# frozen_string_literal: true

require 'fileutils'
require 'time'

require 'photein/media_file'
require 'mediainfo'
require 'mini_exiftool'
require 'streamio-ffmpeg'
require 'tzinfo'
require 'wheretz'
require_relative '../../vendor/terminal-size/lib/terminal-size'

module Photein
  class Video < MediaFile
    FFMPEG.logger.warn!

    SUPPORTED_FORMATS = %w(
      .mov
      .mp4
      .webm
    ).freeze

    OPTIMIZATION_FORMAT_MAP = {
      desktop: { '.mov'  => '.mp4' },
      web: { '.mov'  => '.mp4' }
    }.freeze

    BITRATE_THRESHOLD = {
      desktop: 8388608, # 1MB/s
      web:     2097152, # 0.25MB/s
    }.freeze

    TARGET_CRF = {
      desktop: '28',
      web:     '35',
    }.freeze

    def optimize(tempfile:, lib_type:)
      return if lib_type == :master
      return if video.bitrate < BITRATE_THRESHOLD[lib_type]

      Photein.logger.info("transcoding #{tempfile}")
      return if Photein::Config.dry_run

      video.transcode(
        tempfile.to_s,
        [
          '-map_metadata', '0', # https://video.stackexchange.com/a/26076
          '-movflags',     'use_metadata_tags',
          '-c:v',          'libx264',
          '-crf',          TARGET_CRF[lib_type],
        ],
        &method(:display_progress_bar)
      )
    end

    private

    def corrupted?
      super(video.bitrate.nil?)
    end

    def video
      @video ||= FFMPEG::Movie.new(path.to_s)
    rescue Errno::ENOENT
      Photein.logger.error('ffmpeg is required to manipulate video files')
      raise
    end

    # Video timestamps are typically UTC, and must be adjusted to local TZ.
    # Look for GPS tags first, then default to system local TZ.
    def metadata_stamp
      exif = MiniExiftool.new(path.to_s)

      MediaInfo.from(path.to_s).general.encoded_date&.then do |utc_timestamp|
        if exif.gps_latitude && exif.gps_longitude
          WhereTZ.get(*gps_coords(exif)).to_local(utc_timestamp)
        else
          utc_timestamp.getlocal
        end
      end
    rescue MediaInfo::EnvironmentError
      Photein.logger.error('mediainfo is required to read timestamp metadata')
      raise
    end

    def gps_coords(exif)
      [exif.gps_latitude, exif.gps_longitude].map do |str|
        # `str' follows the format %(xx deg xx' xx.xx" x)
        str.split(/[^\d.NESW]+/).then do |deg, min, sec, dir|
          (deg.to_i + (min.to_f / 60) + (sec.to_f / 3600)) * (%(N E).include?(dir) ? 1 : -1)
        end
      end
    end

    # NOTE: This may be largely unnecessary:
    # metadata timestamps are generally present in all cases except WhatsApp
    def filename_stamp
      path.basename(path.extname).to_s.then do |filename|
        case filename
        when /^LINE_MOVIE_\d{13}$/ # LINE: UNIX time in milliseconds (at download)
          Time.strptime(filename[0..-4], 'LINE_MOVIE_%s')
        when /^VID-\d{8}-WA\d{4}$/ # WhatsApp: date + counter (at receipt)
          Time.strptime(filename, 'VID-%Y%m%d-WA%M%S')
        when /^VID_\d{8}_\d{6}_\d{3}$/ # Telegram: datetime in milliseconds (at download)
          Time.strptime(filename, 'VID_%Y%m%d_%H%M%S_%L')
        when /^signal-\d{4}-\d{2}-\d{2}-\d{6}( \(\d+\))?$/ # Signal: datetime + optional counter (at receipt)
          Time.strptime(filename[0, 24], 'signal-%F-%H%M%S')
        else
          super
        end
      end
    end

    def display_progress_bar(progress)
      return unless $stdout.tty?

      percentage   = "#{(progress * 100).to_i.to_s}%".rjust(5)
      window_width = Terminal.size[:width]
      bar_len      = window_width - 7
      progress_len = (bar_len * progress).to_i
      bg_len       = bar_len - progress_len
      progress_bar = "[#{'#' * progress_len}#{'-' * bg_len}]#{percentage}"
      print "#{progress_bar}\r"
    end
  end
end
