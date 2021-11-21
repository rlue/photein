# frozen_string_literal: true

require 'fileutils'
require 'io/console'
require 'open3'
require 'time'

module Photein
  class MediaFile
    DATE_FORMAT = '%F_%H%M%S'.freeze

    NORMAL_EXTNAME_MAP = {
      '.jpeg' => '.jpg'
    }.freeze

    attr_reader :path

    def initialize(path)
      @path = Pathname(path)
    end

    def import
      return if corrupted?
      return if Photein::Config.interactive && denied_by_user?
      return if Photein::Config.safe && in_use?
      return if Photein::Config.optimize_for && non_optimizable_format?

      FileUtils.mkdir_p(parent_dir, noop: Photein::Config.dry_run)

      optimize if Photein::Config.optimize_for

      Photein::Logger.info(<<~MSG.chomp)
        #{Photein::Config.keep ? 'copying' : 'moving'} #{path.basename} to #{dest_path}
      MSG

      if File.exist?(tempfile)
        FileUtils.mv(tempfile, dest_path, noop: Photein::Config.dry_run)
      else
        FileUtils.cp(path, dest_path, noop: Photein::Config.dry_run)
        FileUtils.chmod('-x', dest_path, noop: Photein::Config.dry_run)
      end

      FileUtils.rm(path, noop: Photein::Config.dry_run || Photein::Config.keep)
    end

    private

    def corrupted?(result = false)
      return result.tap do |r|
        Photein::Logger.error("#{path.basename}: cannot import corrupted file") if r
      end
    end

    def denied_by_user?
      $stdout.printf "Import #{path}? [y/N]"
      (STDIN.getch.downcase != 'y').tap { $stdout.puts }
    end

    def in_use?
      out, _err, status = Open3.capture3("lsof '#{path}'")

      if status.success? # Do open files ALWAYS return exit status 0? (I think so.)
        cmd, pid = out.lines[1]&.split&.first(2)
        Photein::Logger.fatal("skipping #{path}: file in use by #{cmd} (PID #{pid})")
        return true
      else
        return false
      end
    end

    def non_optimizable_format? # may be overridden by subclasses
      return false
    end

    def parent_dir
      Pathname(Photein::Config.dest).join(timestamp.strftime('%Y'))
    end

    def tempfile
      Pathname(Dir.tmpdir).join('photein')
        .tap(&FileUtils.method(:mkdir_p))
        .join(dest_path.basename)
    end

    def dest_path
      @dest_path ||= begin
                       base_path = parent_dir.join("#{timestamp.strftime(DATE_FORMAT)}#{dest_extname}")
                       counter   = resolve_name_collision(base_path.sub_ext("*#{dest_extname}"))

                       base_path.sub_ext("#{counter}#{dest_extname}")
                     end
    end

    def timestamp
      @timestamp ||= (metadata_stamp || filename_stamp)
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

    def dest_extname
      self.class::OPTIMIZATION_FORMAT_MAP
        .dig(Photein::Config.optimize_for, extname) || extname
    end

    def extname
      @extname ||= NORMAL_EXTNAME_MAP[path.extname.downcase] || path.extname.downcase
    end

    def resolve_name_collision(collision_glob)
      case Dir[collision_glob].length
      when 0 # if no files found, no biggie
      when 1 # if one file found, WITH OR WITHOUT COUNTER, reset counter to a
        if Dir[collision_glob].first != collision_glob.sub('*', 'a') # don't try if it's already a lone, correctly-countered file
          Photein::Logger.info('conflicting timestamp found; adding counter to existing file')
          FileUtils.mv(Dir[collision_glob].first, collision_glob.sub('*', 'a'), noop: Photein::Config.dry_run)
        end
      else # TODO: if multiple files found, rectify them?
      end

      # return the next usable counter
      Dir[collision_glob].max&.slice(/.(?=#{Regexp.escape(collision_glob.extname)})/)&.next
        .tap { |counter| raise 'Unresolved timestamp conflict' unless [*Array('a'..'z'), nil].include?(counter) }
    end
  end
end
