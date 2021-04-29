# frozen_string_literal: true

require 'fileutils'
require 'time'

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
      FileUtils.rm(path, noop: Archivist::Config.dry_run || Archivist::Config.keep)
      Archivist::Logger.info("> #{import_method} #{tempfile} #{dest_path.sub_ext('.mp4')}")
      FileUtils.send(import_method, tempfile, dest_path.sub_ext('.mp4'), noop: Archivist::Config.dry_run)

      return true
    end

    private

    def tempfile
      Pathname.new('/tmp').join(dest_path.basename.sub_ext('.mp4'))
    end

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
          File.mtime(path)
        end
      end
    end
  end
end
