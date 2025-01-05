# frozen_string_literal: true

require 'fileutils'
require 'time'

require 'photein/media_file'
require 'mini_exiftool'
require 'mini_magick'
require 'optipng'

module Photein
  class Image < MediaFile
    SUPPORTED_FORMATS = %w(
      .jpg
      .jpeg
      .dng
      .heic
      .png
    ).freeze
    OPTIMIZATION_FORMAT_MAP = {
      web: { '.heic' => '.jpg' }
    }.freeze
    MAX_RES_WEB = 2097152 # 2MP

    def optimize(tempfile:, lib_type:)
      return unless lib_type == :web

      case extname
      when '.jpg', '.heic'
        return false if image.dimensions.reduce(&:*) < MAX_RES_WEB

        Photein.logger.info "optimizing #{path}"
        MiniMagick::Tool::Convert.new do |convert|
          convert << path
          convert.colorspace('sRGB')
          convert.define('jpeg:dct-method=float')
          convert.interlace('JPEG')
          convert.quality('85%')
          convert.resize("#{MAX_RES_WEB}@>")
          convert.sampling_factor('4:2:0')
          convert << tempfile
        end unless config.dry_run
      when '.png'
        FileUtils.cp(path, tempfile, noop: config.dry_run)
        Photein.logger.info "optimizing #{path}"
        begin
          Optipng.optimize(tempfile, level: 4) unless config.dry_run
        rescue Errno::ENOENT
          Photein.logger.error('optipng is required to compress PNG images')
          raise
        end
      end
    end

    private

    def image
      @image ||= MiniMagick::Image.open(path)
    rescue MiniMagick::Invalid => e
      Photein.logger.error(<<~MSG) if e.message.match?(/You must have ImageMagick/)
        ImageMagick is required to manipulate image files
      MSG
      raise
    end

    def timestamp_from_metadata
      MiniExiftool.new(path.to_s).date_time_original
    rescue MiniExiftool::Error => e
      Photein.logger.error(<<~MSG) if e.message.match?(/exiftool: not found/)
        exiftool is required to read timestamp metadata
      MSG
      raise
    end

    # NOTE: This may be largely unnecessary:
    # metadata timestamps are generally present in all cases except WhatsApp
    def timestamp_from_filename
      path.basename(path.extname).to_s.then do |filename|
        case filename
        when /^IMG_\d{8}_\d{6}(_\d{3})?$/ # Android DCIM: datetime + optional counter
          Time.strptime(filename[0, 19], 'IMG_%Y%m%d_%H%M%S')
        when /^\d{13}$/ # LINE: UNIX time in milliseconds (at download)
          Time.strptime(filename[0..-4], '%s')
        when /^IMG-\d{8}-WA\d{4}$/ # WhatsApp: date + counter (at receipt)
          Time.strptime(filename, 'IMG-%Y%m%d-WA%M%S')
        when /^IMG_\d{8}_\d{6}_\d{3}$/ # Telegram: datetime in milliseconds (at download)
          Time.strptime(filename, 'IMG_%Y%m%d_%H%M%S_%L')
        when /^signal-\d{4}-\d{2}-\d{2}-\d{6}( \(\d+\))?$/ # Signal: datetime + optional counter (at receipt)
          Time.strptime(filename[0, 24], 'signal-%F-%H%M%S')
        when /^\d{13}$/ # LINE: UNIX time in milliseconds (at download)
          Time.strptime(filename[0..-4], '%s')
        else
          super
        end
      end
    end

    def non_optimizable_format?(lib_type)
      return true if lib_type == :web && extname == '.dng'

      return false
    end

    def update_exif_tags(path)
      return if config.timestamp_delta.zero? && config.local_tz.nil?

      file = MiniExiftool.new(path)
      file.all_dates = new_timestamp.strftime('%Y:%m:%d %H:%M:%S') if config.timestamp_delta != 0

      if !config.local_tz.nil?
        new_timestamp.to_s                                           # "2020-02-14 22:55:30 -0800"
          .split.tap(&:pop).join(' ').then { |time| time + ' UTC' }  # "2020-02-14 22:55:30 UTC"
          .then(&Time.method(:parse))                                # 2020-02-14 22:55:30 UTC
          .then(&config.local_tz.method(:to_local))                  # 2020-02-14 22:55:30 +0800
          .strftime('%z').insert(3, ':')                             # "+08:00"
          .tap { |offset| file.offset_time = offset }
          .tap { |offset| file.offset_time_digitized = offset }
          .tap { |offset| file.offset_time_original = offset }
      end

      file.save!
    end
  end
end
