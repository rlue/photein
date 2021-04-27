# frozen_string_literal: true

require 'fileutils'

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
      FileUtils.rm(path) unless Archivist::Config.dry_run || Archivist::Config.keep

      return true
    end
  end
end
