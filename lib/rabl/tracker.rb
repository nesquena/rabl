module Rabl
  class Tracker
    # Matches:
    #   extends "categories/show"
    EXTENDS_DEPENDENCY = /
      extends\s*              # extends, followed by optional whitespace
      \(?                     # start an optional parenthesis for the extends call
      \s*["']([a-z_\/\.]+)    # the template name itself -- 2nd capture
    /x

    # Matches:
    #   partial "categories/show"
    PARTIAL_DEPENDENCY = /
      partial\s*              # extends, followed by optional whitespace
      \(?                     # start an optional parenthesis for the extends call
      \s*["']([a-z_\/\.]+)    # the template name itself -- 2nd capture
    /x

    def self.call(name, template)
      new(name, template).dependencies
    end

    def initialize(name, template)
      @name, @template = name, template
    end

    def dependencies
      (extends_dependencies + partial_dependencies).uniq
    end

    attr_reader :name, :template
    private :name, :template

    private

      def source
        template.source
      end

      def directory
        name.split("/")[0..-2].join("/")
      end

      def extends_dependencies
        source.scan(EXTENDS_DEPENDENCY).flatten
      end

      def partial_dependencies
        source.scan(PARTIAL_DEPENDENCY).flatten
      end
  end
end
