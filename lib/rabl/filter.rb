module Rabl
  # @attr_reader [Rabl::Engine] engine
  class Filter
    attr_reader :fields, :parent

    def initialize(query_string, parent=nil)
      @query_string = query_string
      @parent       = parent
      parse_filter
    end

    def has_filter_for?(node)
      get_filter(node) != nil
    end

    def get_filter(node)
      @fields.find {|f| f.node.to_sym == node.to_sym }
    end

    def execute_functions_in(object, from)
      if has_filter_for? from and not get_filter(from).functions.blank?
        filter = get_filter(from)
        regexp_fns = Regexp.new '(\.?(?<fn>' + functions_permitted + ')\((?<params>[^\)]*)\))'
        scan = filter.functions.scan regexp_fns
        scan.each do |fn|
          object = object.send(function_methods[fn[0].to_sym], fn[1]) if object.respond_to? fn[0]
        end
      end
      object
    end

    protected

    def parse_filter
      @fields = parser @query_string
    end

    def parser(fields)
      regexp = Regexp.new '((?<node>\w+)(?<functions>(\.(' + functions_permitted + ')\(([\w ]+)\))*)(\{(?<fields>.+)\})*),?'
      content = fields.to_s.scan regexp
      content.collect {|c| FilterField.new(c[0], c[1], c[2], parent)}
    end

    def functions_permitted
      [
          :limit,
          :sort
      ].join '|'
    end

    def function_methods
      {
          limit: :limit,
          sort: :order
      }
    end
  end
end