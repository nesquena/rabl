# RABL #

RABL (Ruby API Builder Language) is a ruby templating system for Rails and [Padrino](http://padrinorb.com) that takes a new approach to generating JSON and other formats. Rather than using the ActiveRecord 'to_json', I generally find myself wanting a more expressive and powerful system for generating my APIs. This is especially important when the json representation is complex or doesn't match the exact schema defined in the database itself.

There were a few things in particular I wanted to do easily:

 * Create arbitrary nodes named based on combining data in an object
 * Include nodes only if a certain condition is met
 * Pass arguments to methods and store the result as a child node
 * Partial templates and inheritance to reduce code duplication
 * Easily renaming attributes from their name in the model
 * Simple way to append attributes from a child into the parent

The list goes on. Anyone who has used the 'to_json' approach used in ActiveRecord for generating a json response has felt the pain of the extremely restrictive system. RABL is a general templating system created to solve all of those problems. When I created RABL, I wanted a simple, expressive DRY ruby DSL for defining JSON responses for my APIs.

## Installation ##

Install as a gem:

    gem install rabl

or add to your Gemfile:

    # Gemfile
    gem 'rabl'

and run `bundle install` to install the dependency.

If you are using Rails 2.X or Padrino, RABL works without configuration. With Sinatra, or any other tilt-based framework, simply register:

    Rabl.register!

and RABL will be initialized and ready for use.

## Usage ##

### Object Assignment ###

To declare the data object for use in the template:

     # app/views/users/show.json.rabl
     object @user

or a collection works:

     object @users

and this will be used as the default data object for the rendering.

### Attributes ###

Basic usage of the templater to define a few simple attributes for the response:

    # app/views/users/show.json.rabl
    attributes :id, :foo, :bar

or use with aliased attributes:

    # Take the value of model attribute `foo` and name the node `bar`
    # { bar : 5 }
    attribute :foo => :bar

or even multiple aliased attributes:

    # { baz : <bar value>, animal : <dog value> }
    attributes :bar => :baz, :dog => :animal

### Child Nodes ###

You can also add child nodes from an arbitrary source:

    child @posts => :foobar do
      attributes :id, :title
    end

or simply use existing model associations:

    # Renders all the 'posts' association
    # from the model into a node called 'foobar'
    child :posts => :foobar do
      attributes :id, :title
    end

### Gluing Attributes ###

You can also append child attributes back to the root node:

    # Appends post_id and post_name to parent json object
    glue @post do
      attributes :id => :post_id, :name => :post_name
    end

Use glue to add additional attributes to the parent object.

### Custom Nodes ###

This will generate a json response based on the result of the code block:

    # app/views/users/show.json.rabl
    code :full_name do |u|
      u.first_name + " " + u.last_name
    end

or a custom node that exists only if a condition is true:

    code(:foo, :if => lambda { |m| m.has_foo? }) do |m|
      m.foo
    end

You can use custom "code" nodes to create flexible representations of a value utilizing all the data from the model.

### Partials ###

Often you need to access sub-objects in order to construct your own custom nodes for more complex associations. You can get access to the rabl representation of another object with:

    code :location do
      { :city => @city, :address => partial("web/users/address", :object => @address) }
    end

or an object associated to the parent model:

    code :location do |m|
      { :city => m.city, :address => partial("web/users/address", :object => m.address) }
    end

You can use this method to construct arbitrarily complex nodes for your APIs.

### Inheritance ###

Another common issue of many template builders is unnecessary code redundancy. Typically many representations of an object across multiple endpoints share common attributes or nodes. The nodes for a 'post' object are probably the same or similar in most references throughout the various endpoints.

RABL has the ability to extend other "base" rabl templates and additional attributes:

    # app/views/users/advanced.json.rabl
    extends "users/base" # another RABL template in "app/views/users/base.json.rabl"

    code :can_drink do |m|
      m.age > 21
    end

You can also extend other rabl templates while constructing child nodes to reduce duplication:

    # app/views/users/show.json.rabl
    child @address do
      extends "address/item"
    end

Using partials and inheritance can significantly reduce code duplication in your templates.

## Issues ##

Check out the [Issues](https://github.com/nesquena/rabl/issues) tab for a full list:

 * I am sloppy and failed to unit test this as I cobbled it together. Don't use it in production until I do, for now this is a fun experiment.
 * No support for Rails 3 yet, need a Railstie
 * No configuration options yet for how to create the json (root nodes) :(
 * Better Tilt template support (precompiling templates)
 * Benchmarks and performance optimizations
 * XML Support and potentially others

## Authors and Contributors ##

Thanks to [Miso](http://gomiso.com) for allowing me to create this for our applications and release this project!

* [Nathan Esquenazi](https://github.com/nesquena) - Creator of the project
* [Arthur Chiu](https://github.com/achiu) - Core Maintainer, Riot Testing Guru
* [Tim Lee](https://github.com/timothy1ee) - RABL is an awesome name and was chosen by the Miso CTO.

More to come hopefully! Please fork and contribute, any help is appreciated!

## Inspirations ##

There are a few excellent libraries that helped inspire RABL and they are listed below:

 * [Tequila](https://github.com/inem/tequila)
 * [JSON Builder](https://github.com/dewski/json_builder)
 * [Argonaut](https://github.com/jbr/argonaut)

Thanks again for all of these great projects.