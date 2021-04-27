# frozen_string_literal: true

require 'fileutils'

require 'archivist/media_file'
require 'streamio-ffmpeg'

module Archivist
  class Video < MediaFile
    def optimize
      video = FFMPEG::Movie.new(path.to_s)
      case Archivist::Config.optimize_for
      when 'desktop'
        return false if video.bitrate < 8388608 # 1MB/s (
      when 'web'
        return false if video.bitrate < 2097152 # 0.25MB/s
      end


      Archivist::Logger.info("transcoding #{path}")
      video.transcode(tempfile.to_s, [
        '-map_metadata', '0', # https://video.stackexchange.com/a/26076
        '-movflags',     'use_metadata_tags',
        '-c:v',          'libx264',
        '-crf',          Archivist::Config.optimize_for == :desktop ? '28' : '35',
      ]) unless Archivist::Config.dry_run

      Archivist::Logger.info("> rm #{path}") unless Archivist::Config.keep
      FileUtils.rm(path) unless Archivist::Config.dry_run || Archivist::Config.keep
      Archivist::Logger.info("> #{import_method} #{tempfile} #{dest_path.sub_ext('.mp4')}")
      FileUtils.send(import_method, tempfile, dest_path.sub_ext('.mp4')) unless Archivist::Config.dry_run

      return true
    end

    private

    def tempfile
      Pathname.new('/tmp').join(dest_path.basename.sub_ext('.mp4'))
    end
  end
end
