class User
  attr_accessor :age, :city, :name, :friends

  DEFAULT_AGE  = 24
  DEFAULT_CITY = 'irvine'
  DEFAULT_NAME = 'rabl'
  DEFAULT_FRIENDS = []

  def initialize(attributes={})
    self.age  = attributes[:age]  || DEFAULT_AGE
    self.city = attributes[:city] || DEFAULT_CITY
    self.name = attributes[:name] || DEFAULT_NAME
    self.friends = attributes[:friends] || DEFAULT_FRIENDS
  end
end

module NestedScope
  class User
    def controller; self; end
    def controller_name; self.class.name.downcase; end
  end
end
