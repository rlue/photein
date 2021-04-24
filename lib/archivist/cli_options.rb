# frozen_string_literal: true

module Archivist
  CLI_OPTIONS = [
    ['-v',             '--verbose',                              'print verbose output'],
    ['-s SOURCE',      '--source=SOURCE',                        'specify the source directory'],
    ['-d DESTINATION', '--dest=DESTINATION',                     'specify the destination directory'],
    ['-V VOLUME',      '--volume=VOLUME',                        'mount a device first (e.g., camera SD card)'],
    ['-r',             '--recursive',                            'ingest source files recursively'],
    ['-k',             '--keep',                                 'do not delete source files'],
    ['-i',             '--interactive',                          'ask whether to import each file found'],
    ['-n',             '--dry-run',                              'perform a "no-op" trial run'],
    [                  '--safe',                                 'skip files in use by other processes'],
    [                  '--optimize-for=TARGET', %i[desktop web], 'compress images/video before importing']
  ].freeze
end

# vim: nowrap
