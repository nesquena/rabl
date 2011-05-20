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

```
gem install rabl
```

or add to your Gemfile:

```ruby
# Gemfile
gem 'rabl'
```

and run `bundle install` to install the dependency.

If you are using **Rails 2.X, Rails 3 or Padrino**, RABL works without configuration.

With Sinatra, or any other tilt-based framework, simply register:

    Rabl.register!

and RABL will be initialized and ready for use.

## Overview ##

The quick idea here is that you can use RABL to generate JSON and XML API based on any arbitrary data source. With RABL, the data is expected to come
primarily from a model (ORM-agnostic) and the representation of the API output is described in the view with a simple ruby DSL. This allows you to keep your data separate from the JSON or XML you wish to output.

Once you have installed RABL (explained above), you can construct a RABL view template and then render the template from your Sinatra, Padrino or Rails applications from the controller (or route) very easily. Using [Padrino](http://padrinorb.com) as an example, assuming you have a `Post` model filled with blog posts, you can render an API representation (both JSON and XML) by creating a route:

```ruby
# app/app.rb
get "/posts", :provides => [:json, :xml] do
  @user = current_user
  @posts = Post.order("id DESC")
  render "posts/index"
end
```

Then we can create the following RABL template to express the API output of `@posts`:

```ruby
# app/views/posts/index.rabl
collection @posts
attributes :id, :title, :subject
child(:user) { attributes :full_name }
node(:read) { |post| post.read_by?(@user) }
```

Which would output the following JSON or XML when visiting `http://localhost:3000/posts.json`

```json
[{  post :
  {
    id : 5, title: "...", subject: "...",
    user : { full_name : "..." },
    read : true
  }
}]
```

That's the basic overview but there is a lot more (partials, inheritance, custom nodes, etc). Read the full details below of RABL below.

## Configuration ##

RABL is intended to require little to no configuration to get working. This is the case in most scenarios, but depending on your needs you may want to set the following global configurations in your application (this block is completely optional):

```ruby
# config/initializers/rabl_init.rb
Rabl.configure do |config|
  # Commented as these are the defaults
  # config.include_json_root = true
  # config.include_xml_root  = false
  # config.enable_json_callbacks = false
  # config.xml_options = { :dasherize  => true, :skip_types => false }
end
```

Each option specifies behavior related to RABL's output. If `include_json_root` is disabled that removes the root node for each child in the output, and `enable_json_callbacks` enables support for 'jsonp' style callback output if the incoming request has a 'callback' parameter.

## Usage ##

### Object Assignment ###

To declare the data object for use in the template:

```ruby
# app/views/users/show.json.rabl
object @user
```

or specify an alias for the object:

```ruby
object @user => :person
# => { "person" : { ... } }
```

or pass a collection of objects:

```ruby
collection @users
# => [ { "user" : { ... } } ]
```

or even specify a root node label for the collection:

```ruby
collection @users => :people
# => { "people" : [ { "person" : { ... } } ] }
```

and this will be used as the default data for the rendering.

There can also be odd cases where the root-level of the response doesn't map directly to any object:

```ruby
object false
code(:some_count) { |m| @user.posts.count }
child(@user) { attribute :name }
```

In those cases, object can be assigned to 'false' and child nodes can be constructed independently.

### Attributes ###

Basic usage of the templater to define a few simple attributes for the response:

```ruby
# app/views/users/show.json.rabl
attributes :id, :foo, :bar
```

or use with aliased attributes:

```ruby
# Take the value of model attribute `foo` and name the node `bar`
attribute :foo => :bar
# => { bar : 5 }
```

or even multiple aliased attributes:

```ruby
attributes :bar => :baz, :dog => :animal
# => # { baz : <bar value>, animal : <dog value> }
```

### Child Nodes ###

Often a response requires including nested information from data associated with the parent model:

```ruby
child :address do
  attributes :street, :city, :zip, :state
end
```

You can also add child nodes from an arbitrary data source:

```ruby
child @posts => :foobar do
  attributes :id, :title
end
```

or use model associations with an alias:

```ruby
# Renders all the 'posts' association
# from the model into a node called 'foobar'
child :posts => :foobar do
  attributes :id, :title
end
```

### Gluing Attributes ###

You can also append child attributes back to the root node:

```ruby
# Appends post_id and post_name to parent json object
glue @post do
  attributes :id => :post_id, :name => :post_name
end
```

Use glue to add additional attributes to the parent object.

### Custom Nodes ###

This will generate a json response based on the result of the code block:

```ruby
# app/views/users/show.json.rabl
code :full_name do |u|
  u.first_name + " " + u.last_name
end
```

or a custom node that exists only if a condition is true:

```ruby
# m is the object being rendered, also supports :unless
code(:foo, :if => lambda { |m| m.has_foo? }) do |m|
  m.foo
end
```

You can use custom "code" nodes to create flexible representations of a value utilizing all the data from the model.

### Partials ###

Often you need to access other data objects in order to construct custom nodes in more complex associations. You can get access to the rabl representation of another data object by rendering a RABL partial:

```ruby
code :location do
  { :city => @city, :address => partial("users/address", :object => @address) }
end
```

or event access an object associated with the parent model:

```ruby
code :location do |m|
  { :city => m.city, :address => partial("users/address", :object => m.address) }
end
```

You can use this method to construct arbitrarily complex nodes for your APIs. Note that you need to have RABL templates defined
for each of the objects you wish to construct representations for in this manner.

### Inheritance ###

Another common issue of many template builders is unnecessary code redundancy. Typically many representations of an object across multiple endpoints share common attributes or nodes. The nodes for a 'post' object are probably the same or similar in most references throughout the various endpoints.

RABL has the ability to extend other "base" rabl templates and additional attributes:

```ruby
# app/views/users/advanced.json.rabl
extends "users/base" # another RABL template in "app/views/users/base.json.rabl"

code :can_drink do |m|
  m.age > 21
end
```

You can also extend other rabl templates while constructing child nodes to reduce duplication:

```ruby
# app/views/users/show.json.rabl
child @address do
  extends "address/item"
end
```

Using partials and inheritance can significantly reduce code duplication in your templates.

### Deep Nesting ###

In APIs, you can often need to construct 2nd or 3rd level nodes. Let's suppose we have a 'quiz' model that has many 'questions'
and then each question has many 'answers'. We can display this hierarchy in RABL quite easily:

```ruby
# app/views/quizzes/show.json.rabl
object @quiz
attribute :title
child :questions do
  attribute :caption
  child :answers do
    # Use inheritance to reduce duplication
    extends "answers/item"
  end
end
```

This will display the quiz object with nested questions and answers as you would expect with a quiz node, and embedded questions and answers.
Note that RABL can be nested arbitrarily deep within child nodes to allow for these representations to be defined.

## Template Scope ##

In RABL, you have access to everything you need to build an API response. Each RABL template has full access to the controllers
instance variables as well as all view helpers and routing urls.

```ruby
# app/some/template.rabl
object @post
# Access instance variables
child(@user => :user) { ... }
# or Rails helpers
code(:formatted_body) { |post| simple_format(post.body) }
```

There should be no problem fetching the appropriate data to construct a response.

## Issues ##

Check out the [Issues](https://github.com/nesquena/rabl/issues) tab for a full list:

 * Better Tilt template support (precompiling templates)
 * Benchmarks and performance optimizations

## Authors and Contributors ##

Thanks to [Miso](http://gomiso.com) for allowing me to create this for our applications and release this project!

* [Nathan Esquenazi](https://github.com/nesquena) - Creator of the project
* [Arthur Chiu](https://github.com/achiu) - Core Maintainer, Riot Testing Guru
* [Tim Lee](https://github.com/timothy1ee) - RABL is an awesome name and was chosen by the Miso CTO.
* [Rick Thomas](https://github.com/rickthomasjr) - Added options passing for extends and Sinatra testing
* [Marjun](https://github.com/mpagalan) - Added xml option configurations

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