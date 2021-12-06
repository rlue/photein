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
        Pathname(Photein::Config.source)
          .join(Photein::Config.recursive ? '**' : '')
          .join("*{#{media_type::SUPPORTED_FORMATS.join(',')}}")
          .then { |glob| Dir.glob(glob, File::FNM_CASEFOLD).sort }
          .map(&media_type.method(:new))
          .each(&:import)
      end
    end
  end
end
