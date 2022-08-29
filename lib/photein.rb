# frozen_string_literal: true

require 'photein/version'
require 'photein/config'
require 'photein/logger'
require 'photein/media_file'
require 'photein/image'
require 'photein/video'

module Photein
  class << self
    def run
      [Photein::Image, Photein::Video].each do |media_type|
        # Why not use Dir.glob? It refuses to do case-insensitive matching on Linux
        ftype_regex = /(#{media_type::SUPPORTED_FORMATS.join('|').gsub('.', '\.')})$/i

        Pathname(Photein::Config.source)
          .join(Photein::Config.recursive ? '**' : '', '*')
          .select { |file| file.match?(ftype_regex) }
          .map(&media_type.method(:new))
          .each(&:import)
      end
    end
  end
end
