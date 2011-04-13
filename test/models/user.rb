require 'mongoid'

class User
  include Mongoid::Document

  field :name, :type => String,  :default => 'rabl'
  field :city, :type => String,  :default => 'irvine'
  field :age,  :type => Integer, :default => 24
end
