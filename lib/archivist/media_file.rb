# frozen_string_literal: true

require 'fileutils'
require 'io/console'
require 'open3'

require 'mini_exiftool'

module Archivist
  class MediaFile
    DATE_FORMAT = '%F_%H%M%S'.freeze

    attr_reader :path

    def initialize(path)
      @path = Pathname.new(path)
    end

    def import
      return if Archivist::Config.interactive && denied_by_user?
      return if Archivist::Config.safe && in_use?

      FileUtils.mkdir_p(parent_dir) unless Archivist::Config.dry_run

      return if Archivist::Config.optimize_for && optimize

      Archivist::Logger.info("> #{import_method} #{path} #{dest_path}")
      FileUtils.send(import_method, path, dest_path) unless Archivist::Config.dry_run
      FileUtils.chmod('-x', dest_path) unless Archivist::Config.dry_run
    end

    private

    def denied_by_user?
      STDOUT.printf "Import #{path}? [y/N]"
      (STDIN.getch.downcase != 'y').tap { STDOUT.puts }
    end

    def in_use?
      out, _err, status = Open3.capture3("lsof '#{path}'")
      return false if status.to_i > 0 # Do open files ALWAYS return exit status 0?

      cmd, pid = out.lines[1]&.split&.first(2)
      Archivist::Logger.fatal("skipping #{path}: file in use by #{cmd} (PID #{pid})")
      return true
    end

    def parent_dir
      Pathname.new(Archivist::Config.dest).join(timestamp.strftime('%Y'))
    end

    def import_method
      @import_method ||= Archivist::Config.keep ? :cp : :mv
    end

    def dest_path
      @dest_path ||= begin
                       base_path = parent_dir.join("#{timestamp.strftime(DATE_FORMAT)}#{extname}")
                       counter   = resolve_name_collision(base_path.sub_ext("*#{extname}"))

                       base_path.sub_ext("#{counter}#{extname}")
                     end
    end

    def timestamp
      MiniExiftool.new(path).create_date || File.mtime(path)
    end

    def extname
      path.extname.downcase
    end

    def resolve_name_collision(collision_glob)
      case Dir[collision_glob].length
      when 0 # if no files found, no biggie
      when 1 # if one file found, WITH OR WITHOUT COUNTER, reset counter to a
        Archivist::Logger.info('conflicting timestamp found; adding counter to existing file')
        FileUtils.mv(Dir[collision_glob].first, collision_glob.sub('*', 'a'))
      else # TODO: if multiple files found, rectify them?
      end

      # return the next usable counter
      Dir[collision_glob].max&.slice(/.(?=#{Regexp.escape(collision_glob.extname)})/)&.next
        .tap { |counter| raise 'Unresolved timestamp conflict' unless [*Array('a'..'z'), nil].include?(counter) }
    end
  end
end
