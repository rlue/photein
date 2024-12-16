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

      Photein::Config.destinations.map do |lib_type, lib_path|
        next if non_optimizable_format?(lib_type)

        Thread.new do
          dest_basename = timestamp.strftime(DATE_FORMAT)
          dest_extname  = self.class::OPTIMIZATION_FORMAT_MAP.dig(lib_type, extname) || extname
          dest_path     = lib_path
                            .join(timestamp.strftime('%Y'))
                            .join("#{dest_basename}#{dest_extname}")
                            .then(&method(:resolve_name_collision))
          tempfile      = Pathname(Dir.tmpdir)
                            .join('photein').join(lib_type.to_s)
                            .tap(&FileUtils.method(:mkdir_p))
                            .join(dest_path.basename)

          optimize(tempfile: tempfile, lib_type: lib_type)

          Photein.logger.info(<<~MSG.chomp)
            #{Photein::Config.keep ? 'copying' : 'moving'} #{path.basename} to #{dest_path}
          MSG

          FileUtils.mkdir_p(dest_path.dirname, noop: Photein::Config.dry_run)

          if File.exist?(tempfile)
            FileUtils.mv(tempfile, dest_path, noop: Photein::Config.dry_run)
          else
            FileUtils.cp(path, dest_path, noop: Photein::Config.dry_run)
            FileUtils.chmod('-x', dest_path, noop: Photein::Config.dry_run)
          end
        end
      end.compact.map(&:join).then do |threads|
        # e.g.: with --library-web only, .dngs are skipped, so DON'T DELETE!
        FileUtils.rm(path, noop: threads.empty? || Photein::Config.dry_run || Photein::Config.keep)
      end
    end

    private

    def corrupted?(result = false)
      return result.tap do |r|
        Photein.logger.error("#{path.basename}: cannot import corrupted file") if r
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
        Photein.logger.fatal("skipping #{path}: file in use by #{cmd} (PID #{pid})")
        return true
      else
        return false
      end
    end

    def non_optimizable_format?(lib_type = :master) # may be overridden by subclasses
      return false
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

    def extname
      @extname ||= NORMAL_EXTNAME_MAP[path.extname.downcase] || path.extname.downcase
    end

    def resolve_name_collision(filename)
      raise ArgumentError, 'Invalid filename' if filename.to_s.include?('*')

      collision_glob = Pathname(filename).sub_ext("*#{filename.extname}")

      case Dir[collision_glob].length
      when 0 # if no files found, no biggie
      when 1 # if one file found, WITH OR WITHOUT COUNTER, reset counter to a
        if Dir[collision_glob].first != collision_glob.sub('*', 'a') # don't try if it's already a lone, correctly-countered file
          Photein.logger.info('conflicting timestamp found; adding counter to existing file')
          FileUtils.mv(Dir[collision_glob].first, collision_glob.sub('*', 'a'), noop: Photein::Config.dry_run)
        end
      else # TODO: if multiple files found, rectify them?
      end

      # return the next usable filename
      Dir[collision_glob].max&.slice(/.(?=#{Regexp.escape(collision_glob.extname)})/)&.next
        .tap { |counter| raise 'Unresolved timestamp conflict' unless [*Array('a'..'z'), nil].include?(counter) }
        .then { |counter| filename.sub_ext("#{counter}#{filename.extname}") }
    end

    class << self
      def for(file)
        file = Pathname(file)
        raise Errno::ENOENT, "#{file}" unless file.exist?

        [Image, Video].find { |type| type::SUPPORTED_FORMATS.include?(file.extname.downcase) }
          .tap { |type| raise ArgumentError, "#{file}: Invalid media file" if type.nil? }
          .then { |type| type.new(file) }
      end
    end
  end
end
