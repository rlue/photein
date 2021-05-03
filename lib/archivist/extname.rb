# frozen_string_literal: true

module Archivist
  class Extname
    NORMAL_EXTNAME_MAP = {
      '.jpeg' => '.jpg'
    }.freeze

    def initialize(extname)
      extname = extname.extname if extname.respond_to?(:extname)

      @raw = extname
      @normalized = NORMAL_EXTNAME_MAP[extname.downcase] || extname.downcase
    end

    def to_s
      @normalized
    end

    def raw
      @raw
    end

    def ==(arg)
      (to_s == arg) || super
    end

    def method_missing(m, *args, &block)
      return super unless m.to_s.match?(/^[a-zA-Z0-9]{3,4}\?$/)

      m.to_s == "#{@normalized.delete('.')}?"
    end

    def respond_to_missing?(m, *args)
      m.to_s.match?(/^[a-zA-Z0-9]{3,4}\?$/) || super
    end
  end
end

class String
  def ===(arg)
    return self.===(arg.to_s) if arg.is_a?(Archivist::Extname)

    super
  end
end
