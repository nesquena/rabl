require 'mongoid'

class Admin
  include Mongoid::Document

  field :name, :type => String,  :default => 'rabl_admin'
  field :phone, :type => String, :default => '555-1212'
end