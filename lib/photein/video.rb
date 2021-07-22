# frozen_string_literal: true

require 'fileutils'
require 'time'

require 'photein/media_file'
require 'mediainfo'
require 'streamio-ffmpeg'
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

    def optimize
      return if video.bitrate < BITRATE_THRESHOLD[Photein::Config.optimize_for]

      Photein::Logger.info("transcoding #{tempfile}")
      return if Photein::Config.dry_run

      video.transcode(
        tempfile.to_s,
        [
          '-map_metadata', '0', # https://video.stackexchange.com/a/26076
          '-movflags',     'use_metadata_tags',
          '-c:v',          'libx264',
          '-crf',          TARGET_CRF[Photein::Config.optimize_for],
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
    end

    def metadata_stamp
      # video timestamps are typically UTC
      MediaInfo.from(path.to_s).general.encoded_date&.getlocal
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
