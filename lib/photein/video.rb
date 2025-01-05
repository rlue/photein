# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'time'

require 'photein/media_file'
require 'active_support/core_ext/string/zones'
require 'active_support/core_ext/time/zones'
require 'active_support/values/time_zone'
require 'mediainfo'
require 'mini_exiftool'
require 'streamio-ffmpeg'
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
      return if config.dry_run

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
    def timestamp_from_metadata
      MediaInfo.from(path.to_s).general.encoded_date
    rescue MediaInfo::EnvironmentError
      Photein.logger.error('mediainfo is required to read timestamp metadata')
      raise
    end

    # NOTE: This may be largely unnecessary:
    # metadata timestamps are generally present in all cases except WhatsApp
    def timestamp_from_filename
      path.basename(path.extname).to_s.then do |filename|
        case filename
        when /^LINE_MOVIE_\d{13}$/ # LINE: UNIX time in milliseconds (at download)
          local_tz.strptime(filename[0..-4], 'LINE_MOVIE_%s')
        when /^VID-\d{8}-WA\d{4}$/ # WhatsApp: date + counter (at receipt)
          local_tz.strptime(filename, 'VID-%Y%m%d-WA%M%S')
        when /^VID_\d{8}_\d{6}_\d{3}$/ # Telegram: datetime in milliseconds (at download)
          local_tz.strptime(filename, 'VID_%Y%m%d_%H%M%S_%L')
        when /^signal-\d{4}-\d{2}-\d{2}-\d{6}( \(\d+\))?$/ # Signal: datetime + optional counter (at receipt)
          local_tz.strptime(filename[0, 24], 'signal-%F-%H%M%S')
        else
          super&.asctime&.in_time_zone(local_tz)
        end
      end&.utc
    end

    def timestamp_from_filesystem
      super.asctime.in_time_zone(local_tz).utc
    end

    def dest_filename
      @dest_filename ||= local_tz.tzinfo.to_local(new_timestamp).strftime(DATE_FORMAT)
    end

    def local_tz
      @local_tz ||= ActiveSupport::TimeZone[
        MiniExiftool.new(path).then(&method(:gps_coords))&.then(&method(:coords_to_tz)) ||
        config.local_tz ||
        Time.now.gmt_offset
      ]
    end

    def gps_coords(exif)
      return nil if exif.gps_latitude.nil? || exif.gps_longitude.nil?

      [exif.gps_latitude, exif.gps_longitude].map do |str|
        # `str' follows the format %(xx deg xx' xx.xx" x)
        str.split(/[^\d.NESW]+/).then do |deg, min, sec, dir|
          (deg.to_i + (min.to_f / 60) + (sec.to_f / 3600)) * (%(N E).include?(dir) ? 1 : -1)
        end
      end
    end

    def coords_to_tz(coords)
      # WhereTZ::get() can return a single element OR an array -_-'
      Array(WhereTZ.get(coords[0], coords[1])).first
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

    def update_exif_tags(path)
      return if config.timestamp_delta.zero? && config.local_tz.nil?

      args = []
      args.push("-AllDates=#{new_timestamp.strftime('%Y:%m:%d\\ %H:%M:%S')}") if config.timestamp_delta != 0

      if (lat, lon = config.tz_coordinates)
        args.push("-xmp:GPSLatitude=#{lat}")
        args.push("-xmp:GPSLongitude=#{lon}")
      end

      system("exiftool -overwrite_original #{args.join(' ')} #{path}", out: File::NULL, err: File::NULL)
    end
  end
end
