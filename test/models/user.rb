unless defined?(User)
  class User
    attr_accessor :age, :city, :name, :first, :float, :hobbies

    DEFAULT_AGE      = 24
    DEFAULT_CITY     = 'irvine'
    DEFAULT_NAME     = 'rabl'
    DEFAULT_FIRST    = 'bob'
    DEFAULT_FLOAT    = 1234.56
    DEFAULT_HOBBIES  = ['Photography']

    def initialize(attributes={})
      self.age     = attributes[:age]     || DEFAULT_AGE
      self.city    = attributes[:city]    || DEFAULT_CITY
      self.name    = attributes[:name]    || DEFAULT_NAME
      self.first   = attributes[:first]   || DEFAULT_FIRST
      self.float   = attributes[:float]   || DEFAULT_FLOAT
      self.hobbies = (attributes[:hobbies] || DEFAULT_HOBBIES).map { |h| Hobby.new(h) }
    end
  end

  class Hobby
    attr_accessor :name
    def initialize(name); @name = name; end
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
