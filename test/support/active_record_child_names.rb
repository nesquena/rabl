# frozen_string_literal: true

# Renders each template given in ARGV against an in-memory ActiveRecord schema whose
# association names differ from their table names, one JSON document per line (#394).
# Run in a subprocess by test/child_name_test.rb, so the main test process never loads
# ActiveRecord (and the ActiveSupport JSON extensions that come with it).
require 'json'
require 'active_record'
require 'rabl'

ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:products)           { |t| t.string :name }
  create_table(:product_units)      { |t| t.string :name; t.integer :product_id }
  create_table(:product_components) { |t| t.integer :product_id; t.integer :product_unit_id }
end

class ProductUnit < ActiveRecord::Base; end

class ProductComponent < ActiveRecord::Base
  belongs_to :product_unit
end

class Product < ActiveRecord::Base
  has_many :product_components
  has_many :units, :through => :product_components, :source => :product_unit
  has_many :parts, :class_name => 'ProductUnit'
end

product = Product.create!(:name => 'desk')
ProductComponent.create!(:product_id => product.id, :product_unit_id => ProductUnit.create!(:name => 'leg').id)
ProductUnit.create!(:name => 'top', :product_id => product.id)

ARGV.each do |source|
  puts Rabl::Renderer.new(source, product, :format => 'json', :locals => { :relation => ProductUnit.where(:name => 'top') }).render
end
