# frozen_string_literal: true

require 'fileutils'
require 'time'

require 'archivist/media_file'
require 'mini_magick'
require 'optipng'

module Archivist
  class Image < MediaFile
    OPTIMIZED_FORMAT = '.jpg'
    MAX_RES_WEB = 2097152 # 2MP

    def optimize
      return if Archivist::Config.optimize_for == :desktop

      case extname
      when '.jpg', '.heic'
        return false if image.dimensions.reduce(&:*) < MAX_RES_WEB

        Archivist::Logger.info "optimizing #{path}"
        MiniMagick::Tool::Convert.new do |convert|
          convert << path
          convert.colorspace('sRGB')
          convert.define('jpeg:dct-method=float')
          convert.interlace('JPEG')
          convert.quality('85%')
          convert.resize("#{MAX_RES_WEB}@>")
          convert.sampling_factor('4:2:0')
          convert << tempfile
        end unless Archivist::Config.dry_run
      when '.png'
        return if !Optipng.available?

        FileUtils.cp(path, tempfile, noop: Archivist::Config.dry_run)
        Optipng.optimize(tempfile, level: 4) unless Archivist::Config.dry_run
      end
    end

    private

    def image
      @image ||= MiniMagick::Image.open(path)
    end

    def filename_stamp
      path.basename(path.extname).to_s.then do |filename|
        case filename
        when /^\d{13}$/ # LINE: UNIX time in milliseconds (at download)
          Time.strptime(filename[0..-4], '%s')
        when /^IMG-\d{8}-WA\d{4}$/ # WhatsApp: date + counter (at receipt)
          Time.strptime(filename, 'IMG-%Y%m%d-WA%M%S')
        when /^IMG_\d{8}_\d{6}_\d{3}$/ # Telegram: datetime in milliseconds (at download)
          Time.strptime(filename, 'IMG_%Y%m%d_%H%M%S_%L')
        when /^signal-\d{4}-\d{2}-\d{2}-\d{6}( \(\d+\))?$/ # Signal: datetime + optional counter (at receipt)
          Time.strptime(filename[0, 24], 'signal-%F-%H%M%S')
        else
          File.birthtime(path)
        end
      end
    end

    def non_optimizable_format?
      return false if !Archivist::Config.optimize_for
      return false if Archivist::Config.optimize_for == :desktop
      return true if extname == '.dng'

      return false
    end
  end
end
