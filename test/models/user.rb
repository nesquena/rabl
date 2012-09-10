unless defined?(User)
  class User
    attr_accessor :age, :city, :name, :first

    DEFAULT_AGE   = 24
    DEFAULT_CITY  = 'irvine'
    DEFAULT_NAME  = 'rabl'
    DEFAULT_FIRST = 'bob'

    def initialize(attributes={})
      self.age   = attributes[:age]   || DEFAULT_AGE
      self.city  = attributes[:city]  || DEFAULT_CITY
      self.name  = attributes[:name]  || DEFAULT_NAME
      self.first = attributes[:first] || DEFAULT_FIRST
    end
  end
end

unless defined?(NestedScope::User)
  module NestedScope
    class User
      def controller; self; end
      def controller_name; self.class.name.downcase; end
    end
  end
end
