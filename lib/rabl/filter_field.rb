module Rabl
  class FilterField

    attr_reader :node
    attr_reader :functions
    attr_reader :fields
    attr_reader :parent

    def initialize(node, functions, fields, parent=nil)
      @node      = node
      @functions = functions
      @fields    = fields
      @parent    = parent

      if not @fields.blank?
        @fields = Filter.new @fields, parent_name
      end
    end

    protected

    def parent_name
      node.to_s.underscore.to_sym
    end
  end
end