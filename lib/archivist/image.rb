# frozen_string_literal: true

require 'fileutils'
require 'time'

require 'archivist/media_file'
require 'mini_magick'
require 'optipng'

module Archivist
  class Image < MediaFile
    MAX_RES_WEB = 2097152 # 2MP

    def optimize
      return false if Archivist::Config.optimize_for != :web

      case extname
      when '.jpg'
        image = MiniMagick::Image.open(path)
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
          convert << dest_path
        end unless Archivist::Config.dry_run
      when '.png'
        Optipng.optimize(path, level: 4) unless Archivist::Config.dry_run || !Optipng.available?
        return false # continue with import
      when '.dng'
        return true # skip import
      else
        return false # import as normal
      end

      Archivist::Logger.info "> rm #{path}" unless Archivist::Config.keep
      FileUtils.rm(path, noop: Archivist::Config.dry_run) unless Archivist::Config.keep

      return true
    end

    private

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
          File.mtime(path)
        end
      end
    end
  end
end
