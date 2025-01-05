# frozen_string_literal: true

require 'json'
require 'singleton'
require 'optparse'

require 'tzinfo'

module Photein
  class Config
    include Singleton

    OPTIONS = [
      ['-v',             '--verbose',                 'print verbose output'],
      ['-s SOURCE',      '--source=SOURCE',           'path to the source directory'],
      ['-m MASTER',      '--library-master=MASTER',   'path to a destination directory (master)'],
      ['-d DESKTOP',     '--library-desktop=DESKTOP', 'path to a destination directory (desktop-optimized)'],
      ['-w WEB',         '--library-web=WEB',         'path to a destination directory (web-optimized)'],
      ['-r',             '--recursive',               'ingest source files recursively'],
      ['-k',             '--keep',                    'do not delete source files'],
      ['-i',             '--interactive',             'ask whether to import each file found'],
      ['-n',             '--dry-run',                 'perform a "no-op" trial run'],
      [                  '--shift-timestamp=N',       'adjust metadata timestamps by N hours'],
      [                  '--local-tz=TIMEZONE',       "backfill missing GPS* metadata on videos\n                                     (to name files in local time instead of UTC)"],
      [                  '--safe',                    'skip files in use by other processes']
    ].freeze

    OPTION_NAMES = OPTIONS
      .flatten
      .grep(/^--/)
      .map { |option| option[/\w[a-z\-]+/] }
      .map(&:to_sym)

    SECONDS_PER_HOUR = 60 * 60

    TZ_GEOCOORDS = File.expand_path('../../data/tz_coords.json', File.dirname(__FILE__))
      .then(&File.method(:read))
      .then(&JSON.method(:parse))
      .freeze

    @params = {}

    class << self
      def set(**params)
        @params.replace(params)
      end

      def parse_opts!
        parser = OptionParser.new do |opts|
          opts.version = Photein::VERSION
          opts.banner  = <<~BANNER
            Usage: photein [--version] [-h | --help] [<args>]
          BANNER

          OPTIONS.each { |opt| opts.on(*opt) }
        end.tap { |p| p.parse!(into: @params) }

        @params[:verbose] ||= @params[:'dry-run']

        raise "invalid --shift-timestamp option (must be integer)" if @params.key?(:'shift-timestamp') && !@params[:'shift-timestamp'].match?(/^-?\d+$/)

        if @params.key?(:'local-tz')
          if !TZInfo::Timezone.all_identifiers.include?(@params[:'local-tz'])
            raise 'invalid --local-tz option (must be from IANA tz database)'
          end

          if tz_coordinates.nil?
            raise 'invalid --local-tz option (must reference a location)'
          end
        end

        @params.freeze

        raise "no source directory given" if !@params.key?(:source)
        (%i[library-master library-desktop library-web] & @params.keys)
          .then { |dest_dirs| raise "no destination directory given" if dest_dirs.empty? }
      rescue => e
        warn("#{parser.program_name}: #{e.message}")
        warn(parser.help) if e.is_a?(OptionParser::ParseError)
        exit 1
      end

      def method_missing(m, *args, &blk)
        case m.to_s.tr('_', '-').to_sym
        when *OPTION_NAMES
          @params[m]
        when *OPTION_NAMES.map { |opt| "#{opt}=" }.map(&:to_sym)
          @params[m.to_s.sub(/=$/, '').to_sym] = args.shift
        else
          super
        end
      end

      def respond_to_missing?(m, *args)
        OPTION_NAMES.include?(m.to_s.tr('_', '-').sub(/=$/, '').to_sym) || super
      end

      def source
        @source ||= Pathname(@params[:source])
      end

      def destinations
        @destinations ||= {
          master:  @params[:'library-master'],
          desktop: @params[:'library-desktop'],
          web:     @params[:'library-web']
        }.compact.transform_values(&Pathname.method(:new))
      end

      def timestamp_delta
        @timestamp_delta ||= @params[:'shift-timestamp'].to_i * SECONDS_PER_HOUR
      end

      def local_tz
        @local_tz ||= @params[:'local-tz']&.then(&TZInfo::Timezone.method(:get))
      end

      def tz_coordinates
        @tz_coordinates ||= TZ_GEOCOORDS[@params[:'local-tz']]
      end
    end
  end
end
