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

    def optimize
      return if Photein::Config.optimize_for == :desktop

      case extname
      when '.jpg', '.heic'
        return false if image.dimensions.reduce(&:*) < MAX_RES_WEB

        Photein::Logger.info "optimizing #{path}"
        MiniMagick::Tool::Convert.new do |convert|
          convert << path
          convert.colorspace('sRGB')
          convert.define('jpeg:dct-method=float')
          convert.interlace('JPEG')
          convert.quality('85%')
          convert.resize("#{MAX_RES_WEB}@>")
          convert.sampling_factor('4:2:0')
          convert << tempfile
        end unless Photein::Config.dry_run
      when '.png'
        return if !Optipng.available?

        FileUtils.cp(path, tempfile, noop: Photein::Config.dry_run)
        Optipng.optimize(tempfile, level: 4) unless Photein::Config.dry_run
      end
    end

    private

    def image
      @image ||= MiniMagick::Image.open(path)
    end

    def metadata_stamp
      MiniExiftool.new(path.to_s).date_time_original
    end

    # NOTE: This may be largely unnecessary:
    # metadata timestamps are generally present in all cases except WhatsApp
    def filename_stamp
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

    def non_optimizable_format?
      return false if !Photein::Config.optimize_for
      return false if Photein::Config.optimize_for == :desktop
      return true if extname == '.dng'

      return false
    end
  end
end
