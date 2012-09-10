# Defines the default JSON engine for RABL when rendering JSON is invoked on a template.
# You can define your own json engine by creating an object that responds to the `encode` method
# and setting the corresponding configuration option:
#
#     config.json_engine = ActiveSupport::JSON
#

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
        MultiJson.respond_to?(:use) ?
          MultiJson.use(engine_name_or_class) :
          MultiJson.engine = engine_name_or_class
      rescue RuntimeError => e #
        # Re-raise if engine_name_or_class is invalid
        raise e unless engine_name_or_class.respond_to?(:encode)
        engine_name_or_class
      end
    end
  end # JsonEngine
end # Rabl