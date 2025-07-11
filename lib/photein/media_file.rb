# frozen_string_literal: true

require 'fileutils'
require 'io/console'
require 'open3'
require 'time'

module Photein
  class MediaFile
    DATE_FORMAT = '%F_%H%M%S'

    NORMAL_EXTNAME_MAP = {
      '.jpeg' => '.jpg'
    }.freeze

    attr_reader :config
    attr_reader :path

    def initialize(path, opts: {})
      @path = Pathname(path)
      @config = Photein::Config.with(opts)
    end

    def import
      return if corrupted?
      return if config.interactive && denied_by_user?
      return if config.safe && in_use?

      config.destinations.map do |lib_type, lib_path|
        next if non_optimizable_format?(lib_type)

        Thread.new do
          dest_extname  = self.class::OPTIMIZATION_FORMAT_MAP.dig(lib_type, extname) || extname
          dest_path     = lib_path
                          .join(Time.parse(dest_filename).strftime('%Y'))
                          .join("#{dest_filename}#{dest_extname}")
                          .then(&method(:resolve_name_collision))
          tempfile      = Pathname(Dir.tmpdir)
                          .join('photein').join(lib_type.to_s)
                          .tap(&FileUtils.method(:mkdir_p))
                          .join(dest_path.basename)

          optimize(tempfile: tempfile, lib_type: lib_type)

          Photein.logger.info(<<~MSG.chomp)
            #{config.keep ? 'copying' : 'moving'} #{path.basename} to #{dest_path}
          MSG

          FileUtils.mkdir_p(dest_path.dirname, noop: config.dry_run)

          if File.exist?(tempfile)
            FileUtils.mv(tempfile, dest_path, noop: config.dry_run)
          else
            FileUtils.cp(path, dest_path, noop: config.dry_run)
          end

          FileUtils.chmod(0644, dest_path, noop: config.dry_run)
          update_exif_tags(dest_path.realdirpath.to_s) if !config.dry_run
        end
      end.compact.map(&:join).then do |threads|
        # e.g.: with --library-web only, raw files are skipped, so DON'T DELETE!
        FileUtils.rm(path, noop: threads.empty? || config.dry_run || config.keep)
      end
    end

    private

    def corrupted?(result = false)
      result.tap do |r|
        Photein.logger.error("#{path.basename}: cannot import corrupted file") if r
      end
    end

    def denied_by_user?
      $stdout.printf "Import #{path}? [y/N]"
      (STDIN.getch.downcase != 'y').tap { $stdout.puts }
    end

    def in_use?
      out, _err, status = Open3.capture3("lsof '#{path}'")

      return false unless status.success? # Do open files ALWAYS return exit status 0? (I think so.)

      cmd, pid = out.lines[1]&.split&.first(2)
      Photein.logger.fatal("skipping #{path}: file in use by #{cmd} (PID #{pid})")
      true
    end

    def non_optimizable_format?(_lib_type = :master) # may be overridden by subclasses
      false
    end

    def new_timestamp
      @new_timestamp ||= (
        timestamp_from_metadata ||
        timestamp_from_filename ||
        timestamp_from_filesystem
      ) + config.timestamp_delta
    end

    def timestamp_from_metadata
      raise NotImplementedError
    end

    def timestamp_from_filename
      Time.parse(path.basename(path.extname).to_s)
    rescue ArgumentError
      nil
    end

    def timestamp_from_filesystem
      File.birthtime(path)
    rescue NotImplementedError
      File.mtime(path)
    end

    def dest_filename
      @dest_filename ||= new_timestamp.strftime(DATE_FORMAT)
    end

    def extname
      @extname ||= NORMAL_EXTNAME_MAP[path.extname.downcase] || path.extname.downcase
    end

    def resolve_name_collision(pathname)
      raise ArgumentError, 'Invalid filename' if pathname.to_s.include?('*')

      collisions = Dir[pathname.sub_ext("*#{pathname.extname}")]

      case collisions.length
      when 0
        pathname
      when 1
        pathname.sub_ext("+1#{pathname.extname}")
      else # TODO: what to do for heterogeneous suffixes?
        collisions.tap { |c| c.delete(pathname.to_s) }.max
                  .slice(/(?<=^#{pathname.to_s.delete_suffix(pathname.extname)}).*(?=#{pathname.extname}$)/)
                  .tap { |counter| raise 'Unresolved timestamp conflict' unless counter&.match?(/^\+[1-8]$/) }
                  .then { |counter| pathname.sub_ext("#{counter.next}#{pathname.extname}") }
      end
    end

    def update_exif_tags(path)
      raise NotImplementedError
    end

    class << self
      def for(file, opts: {})
        file = Pathname(file)
        raise Errno::ENOENT, "#{file}" unless file.exist?

        [Image, Video].find { |type| type::SUPPORTED_FORMATS.include?(file.extname.downcase) }
                      .tap { |type| raise ArgumentError, "#{file}: Invalid media file" if type.nil? }
                      .then { |type| type.new(file, opts: opts) }
      end
    end
  end
end
