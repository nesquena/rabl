class User
  attr_accessor :age, :city, :name

  DEFAULT_AGE  = 24
  DEFAULT_CITY = 'irvine'
  DEFAULT_NAME = 'rabl'

  def initialize(attributes={})
    self.age  = attributes[:age]  || DEFAULT_AGE
    self.city = attributes[:city] || DEFAULT_CITY
    self.name = attributes[:name] || DEFAULT_NAME
  end
end
