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
      # Video compression is time-consuming, so save it for last
      Pathname(Photein::Config.source)
        .join(Photein::Config.recursive ? '**' : '')
        .join("*{#{Photein::Image::SUPPORTED_FORMATS.join(',')}}")
        .then { |glob| Dir.glob(glob, File::FNM_CASEFOLD).sort }
        .map(&Photein::Image.method(:new))
        .each(&:import)

      Pathname(Photein::Config.source)
        .join(Photein::Config.recursive ? '**' : '')
        .join("*{#{Photein::Video::SUPPORTED_FORMATS.join(',')}}")
        .then { |glob| Dir.glob(glob, File::FNM_CASEFOLD).sort }
        .map(&Photein::Video.method(:new))
        .each(&:import)
    end
  end
end
