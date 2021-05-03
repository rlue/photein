# frozen_string_literal: true

require 'fileutils'
require 'io/console'
require 'open3'
require 'time'

require 'archivist/extname'
require 'mini_exiftool'

module Archivist
  class MediaFile
    DATE_FORMAT = '%F_%H%M%S'.freeze

    attr_reader :path

    def initialize(path)
      @path = Pathname(path)
    end

    def import
      return if Archivist::Config.interactive && denied_by_user?
      return if Archivist::Config.safe && in_use?
      return if Archivist::Config.optimize_for && non_optimizable_format?

      FileUtils.mkdir_p(parent_dir, noop: Archivist::Config.dry_run)

      optimize if Archivist::Config.optimize_for

      Archivist::Logger.info(<<~MSG.chomp)
        #{Archivist::Config.keep ? 'copying' : 'moving'} #{path.basename} to #{dest_path}
      MSG

      if File.exist?(tempfile)
        FileUtils.mv(tempfile, dest_path, noop: Archivist::Config.dry_run)
      else
        FileUtils.cp(path, dest_path, noop: Archivist::Config.dry_run)
        FileUtils.chmod('-x', dest_path, noop: Archivist::Config.dry_run)
      end

      FileUtils.rm(path, noop: Archivist::Config.dry_run || Archivist::Config.keep)
    end

    private

    def denied_by_user?
      STDOUT.printf "Import #{path}? [y/N]"
      (STDIN.getch.downcase != 'y').tap { STDOUT.puts }
    end

    def in_use?
      out, _err, status = Open3.capture3("lsof '#{path}'")

      if status.success? # Do open files ALWAYS return exit status 0? (I think so.)
        cmd, pid = out.lines[1]&.split&.first(2)
        Archivist::Logger.fatal("skipping #{path}: file in use by #{cmd} (PID #{pid})")
        return true
      else
        return false
      end
    end

    def non_optimizable_format? # may be overridden by subclasses
      return false
    end

    def parent_dir
      Pathname(Archivist::Config.dest).join(timestamp.strftime('%Y'))
    end

    def tempfile
      Pathname('/tmp').join(dest_path.basename.sub_ext(self.class::OPTIMIZED_FORMAT))
    end

    def dest_path
      @dest_path ||= begin
                       base_path = parent_dir.join("#{timestamp.strftime(DATE_FORMAT)}#{extname}")
                       counter   = resolve_name_collision(base_path.sub_ext("*#{extname}"))

                       base_path.sub_ext("#{counter}#{extname}")
                     end
    end

    def timestamp
      @timestamp ||= begin
                       # sometimes #create_date returns `false`
                       metadata_stamp = MiniExiftool.new(path).create_date || nil

                       [metadata_stamp, filename_stamp].compact.min
                     end
    end

    def filename_stamp
      Time.parse(path.basename(path.extname).to_s)
    rescue ArgumentError
      begin
        File.birthtime(path)
      rescue NotImplementedError
        File.mtime(path)
      end
    end

    def extname
      @extname ||= Archivist::Extname.new(path)
    end

    def resolve_name_collision(collision_glob)
      case Dir[collision_glob].length
      when 0 # if no files found, no biggie
      when 1 # if one file found, WITH OR WITHOUT COUNTER, reset counter to a
        if Dir[collision_glob].first != collision_glob.sub('*', 'a') # don't try if it's already a lone, correctly-countered file
          Archivist::Logger.info('conflicting timestamp found; adding counter to existing file')
          FileUtils.mv(Dir[collision_glob].first, collision_glob.sub('*', 'a'))
        end
      else # TODO: if multiple files found, rectify them?
      end

      # return the next usable counter
      Dir[collision_glob].max&.slice(/.(?=#{Regexp.escape(collision_glob.extname)})/)&.next
        .tap { |counter| raise 'Unresolved timestamp conflict' unless [*Array('a'..'z'), nil].include?(counter) }
    end
  end
end
