require 'multi_json'
require 'singleton'

module Rabl
  class JsonEngine
    include Singleton

    attr_reader :current_engine

    def initialize
      @current_engine = MultiJson.respond_to?(:adapter) ? MultiJson.adapter : MultiJson.engine
    end

    def set(engine_name_or_class)
      @current_engine = begin
        MultiJson.respond_to?(:use) ? MultiJson.use(engine_name_or_class) : MultiJson.engine = engine_name_or_class
      rescue
        engine_name_or_class
      end
    end
  end
end