# RABL #

RABL is a ruby templating system for Rails that takes a different approach for generating JSON and other formats. Rather than using the ActiveRecord 'to_json', I generally find myself wanting to use a more expressive and flexible system for generating my Public APIs. This is especially true when I the json doesn't match to the exact schema defined in the database.

There were a few things in particular I wanted to do easily:

 * Create arbitrary nodes named based on combining data in the object
 * Include nodes only if a condition is met
 * Pass arguments to methods and store the result as a node
 * Include partial templates to reduce code duplication
 * Easily rename attributes from their name in the model

This general templating system solves all of those problems.

## Installation ##

Install as a gem:

    gem install rabl

or add to your Gemfile:

    # Gemfile
    gem 'rabl'

and run `bundle install` to install the dependency.

## Usage ##

### Object Assignment ###

To declare the data object to use in the template:

     # app/views/users/show.json.rabl
     object @user

or a collection works:

     object @users

and this will be used as the default data object for the rendering.

### Attributes ###

Basic usage of the templater:

    # app/views/users/show.json.rabl
    attributes :id, :foo, :bar

or with aliased attributes:

    # Take the value of model attribute `foo` and name the node `bar`
    # { bar : 5 }
    attribute :foo => :bar

or multiple aliased attributes:

    # { baz : <bar value>, animal : <dog value> }
    attributes :bar => :baz, :dog => :animal

### Child Nodes ###

You can also add children nodes from an arbitrary object:

    child @posts => :foobar do
      attributes :id, :title
    end

or use existing model associations:

    child :posts => :foobar do
      attributes :id, :title
    end

### Glued Attributes ###

You can also append attributes to the root node:

    glue @post do
      attributes :id => :post_id, :name => :post_name
    end

Use glue to add additional attributes to the parent object.

### Custom Nodes ###

This will generate a json response with the attributes specified. You can also include arbitrary code:

    # app/views/users/show.json.rabl
    code :full_name do |u|
      u.first_name + " " + u.last_name
    end

You can use custom "code" nodes to create flexible representations of a value utilizing data from the model.

### Partials ###

Often you need to access sub-objects in order to construct your own custom nodes for more complex associations. You can get access to the hash representation of another object:

    code :location do
      { :city => @city, :address => partial("web/users/address", :object => @address) }
    end

or an object associated to the parent model:

    code :location do |m|
      { :city => m.city, :address => partial("web/users/address", :object => m.address) }
    end

You can use these to construct arbitrarily complex nodes for APIs.

### Inheritance ###

Another common limitation of many json builders is code redundancy. Typically every representation of an object across endpoints share common attributes or nodes. The nodes for a 'post' object are probably the same or similar in most references throughout the various endpoints.

RABL has the ability to extend other "base" rabl templates and additional attributes:

    # app/views/users/advanced.json.rabl
    extends "users/base" # another RABL template in "app/views/users/base.json.rabl"

    code :can_drink do |m|
      m.age > 21
    end

You can also extend other rabl templates in constructing nodes to reduce duplication:

    # app/views/users/show.json.rabl
    child @address do
      extends "address/item"
    end

Using partials and inheritance can significantly reduce code duplication in your templates.

## Issues ##

 * I am sloppy and once again failed to unit test this. Don't use it in production until I do obviously.