# RABL #

RABL (Ruby API Builder Language) is a Rails and [Padrino](http://padrinorb.com) ruby templating system for generating JSON and XML. When using the ActiveRecord 'to_json' method, I tend to quickly find myself wanting a more expressive and powerful system for generating APIs. This is especially frustrating when the json representation is complex or doesn't match the exact schema defined in the database itself.

I wanted a simple, and flexible system for generating APIs. In particular, I wanted to easily:

 * Create arbitrary nodes named based on combining data in an object
 * Pass arguments to methods and store the result as a child node
 * Partial templates and inheritance to reduce code duplication
 * Easily renaming attributes from their name in the model
 * Simple way to append attributes from a child into the parent
 * Include nodes only if a certain condition is met

Anyone who has tried the 'to_json' method used in ActiveRecord for generating a json response has felt the pain of this restrictive approach. RABL is a general templating system created to solve all of those problems.

## Installation ##

Install RABL as a gem:

    gem install rabl

or add to your Gemfile:

    # Gemfile
    gem 'rabl'

and run `bundle install` to install the dependency.

If you are using **Rails 2.X, Rails 3 or Padrino**, RABL works without configuration.

With Sinatra, or any other tilt-based framework, simply register:

    Rabl.register!

and RABL will be initialized and ready for use.

## Usage ##

### Object Assignment ###

To declare the data object for use in the template:

     # app/views/users/show.json.rabl
     object @user

or specify an alias for the object:

    object @user => :person
    # => { "person" : { ... } }

or pass a collection of objects:

     collection @users
     # => [ { "user" : { ... } } ]

or even specify a root node label for the collection:

    collection @users => :people
    # => { "people" : [ { "person" : { ... } } ] }

and this will be used as the default data for the rendering.

There can also be odd cases where the root-level of the response doesn't map directly to any object:

    object false
    code(:some_count) { |m| @user.posts.count }
    child(@user) { attribute :name }

In those cases, object can be assigned to 'false' and child nodes can be constructed independently.

### Attributes ###

Basic usage of the templater to define a few simple attributes for the response:

    # app/views/users/show.json.rabl
    attributes :id, :foo, :bar

or use with aliased attributes:

    # Take the value of model attribute `foo` and name the node `bar`
    attribute :foo => :bar
    # => { bar : 5 }

or even multiple aliased attributes:

    attributes :bar => :baz, :dog => :animal
    # => # { baz : <bar value>, animal : <dog value> }

### Child Nodes ###

Often a response requires including nested information from data associated with the parent model:

    child :address do
      attributes :street, :city, :zip, :state
    end

You can also add child nodes from an arbitrary data source:

    child @posts => :foobar do
      attributes :id, :title
    end

or use model associations with an alias:

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

    # m is the object being rendered, also supports :unless
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

 * No configuration options yet for how to create the json (root nodes) :(
 * Better Tilt template support (precompiling templates)
 * Benchmarks and performance optimizations

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

## Examples

See the [examples](https://github.com/nesquena/rabl/tree/master/examples) directory.

## Copyright

Copyright © 2011 Nathan Esquenazi. See [MIT-LICENSE](https://github.com/nesquena/rabl/blob/master/MIT-LICENSE) for details.