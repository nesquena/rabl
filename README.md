# RABL #

RABL (Ruby API Builder Language) is a Rails and [Padrino](http://padrinorb.com) ruby templating system for generating JSON, XML, MessagePack, PList and BSON. When using the ActiveRecord 'to_json' method, I tend to quickly find myself wanting a more expressive and powerful solution for generating APIs.
This is especially frustrating when the JSON representation is complex or doesn't match the exact schema defined in the database.

I wanted a simple and flexible system for generating my APIs. In particular, I wanted to easily:

 * Create arbitrary nodes named based on combining data in an object
 * Pass arguments to methods and store the result as a child node
 * Render partial templates and inherit to reduce code duplication
 * Rename or alias attributes to change the name from the model
 * Append attributes from a child into a parent node
 * Include nodes only if a certain condition has been met

Anyone who has tried the 'to_json' method used in ActiveRecord for generating a JSON response has felt the pain of this restrictive approach.
RABL is a general templating system created to solve these problems in an entirely new way.

## Installation ##

Install RABL as a gem:

```
gem install rabl
```

or add to your Gemfile:

```ruby
# Gemfile
gem 'rabl'
# Also add either `json` or `yajl-ruby` as the JSON parser
gem 'yajl-ruby'
```

and run `bundle install` to install the dependency.

If you are using **Rails 2.X, Rails 3.X or Padrino**, RABL works without configuration.

With Sinatra, or any other tilt-based framework, simply register:

    Rabl.register!

and RABL will be initialized and ready for use. For usage with Sinatra, check out
the [Sinatra Usage](https://github.com/nesquena/rabl/wiki/Setup-for-Sinatra) guide.

**Note:** Users have reported a few rendering issues with Rails 3.2.
The [template handler](https://github.com/nesquena/rabl/blob/master/lib/rabl/template.rb) probably needs
a patch to properly support Rails 3.2. Hopefully I can get to it soon but patches are welcome.

## Overview ##

You can use RABL to generate JSON and XML based APIs from any ruby object.
With RABL, the data typically is derived primarily from models (ORM-agnostic) and the representation of the API output is described within
a view template using a simple ruby DSL. This allows you to keep your data separated from the JSON or XML you wish to output.

Once you have installed RABL (explained above), you can construct a RABL view template and then render the template
from your Sinatra, Padrino or Rails applications from the controller (or route) very easily. Using [Padrino](http://padrinorb.com) as an
example, assuming you have a `Post` model filled with blog posts, you can render an API representation (both JSON and XML) by creating a route:

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

That's a basic overview but there is a lot more to see such as partials, inheritance, custom nodes, etc. Read the full details of RABL below.

## Configuration ##

RABL is intended to require little to no configuration to get working. This is the case in most scenarios, but depending on your needs you may want to set the following global configurations in your application (this block is completely optional):

```ruby
# config/initializers/rabl_init.rb
Rabl.configure do |config|
  # Commented as these are defaults
  # config.cache_all_output = false
  # config.cache_sources = false
  # config.json_engine = nil # Any multi\_json engines
  # config.msgpack_engine = nil # Defaults to ::MessagePack
  # config.bson_engine = nil # Defaults to ::BSON
  # config.plist_engine = nil # Defaults to ::Plist::Emit
  # config.include_json_root = true
  # config.include_msgpack_root = true
  # config.include_bson_root = true
  # config.include_plist_root = true
  # config.include_xml_root  = false
  # config.enable_json_callbacks = false
  # config.xml_options = { :dasherize  => true, :skip_types => false }
end
```

Each option specifies behavior related to RABL's output. If `include_json_root` is disabled that removes the
root node for each child in the output, and `enable_json_callbacks` enables support for 'jsonp' style callback
output if the incoming request has a 'callback' parameter.

If `cache_sources` is set to `true`, template lookups will be cached for improved performance.
The cache can be reset manually by running `Rabl.reset_source_cache!` within your application.

If `cache_all_output` is set to `true` then every template including each individual template used as part of a collection will be cached separately.
Additionally, anything within child, glue and partial will also be cached separately.
To cache just a single template, see the section titled 'Caching' below.

Note that the `json_engine` option uses [multi_json](http://intridea.com/2010/6/14/multi-json-the-swappable-json-handler) engine
defaults so that in most cases you **don't need to configure this** directly. If you wish to use yajl as
the primary JSON encoding engine simply add that to your Gemfile:

```ruby
# Gemfile
gem 'yajl-ruby', :require => "yajl"
```

and RABL will automatically start using that engine for encoding your JSON responses!

### Message Pack ###

Rabl also includes optional support for [Message Pack](http://www.msgpack.org/) serialization format using the [msgpack gem](https://rubygems.org/gems/msgpack).
To enable, include the msgpack gem in your project's Gemfile. Then use Rabl as normal with the `msgpack` format (akin to json and xml formats).

```ruby
# Gemfile
gem 'msgpack', '~> 0.4.5'
```

One can additionally use a custom Message Pack implementation by setting the Rabl `msgpack_engine` configuration attribute. This custom message pack engine must conform to the MessagePack#pack method signature.

```ruby
class CustomEncodeEngine
  def self.pack string
    # Custom Encoding by your own engine.
  end
end

Rabl.configure do |config|
  config.msgpack_engine = CustomEncodeEngine
end
```

*NOTE*: Attempting to render the msgpack format without either including the msgpack gem
or setting a `msgpack_engine` will cause an exception to be raised.

### BSON ###

Rabl also includes optional support for [BSON](http://bsonspec.org/) serialization format using the [bson gem](https://rubygems.org/gems/bson).
To enable, include the bson gem in your project's Gemfile. Then use Rabl as normal with the `bson` format (akin to json and xml formats).

```ruby
# Gemfile
gem 'bson', '~> 1.5.2'
```

To use it with Rails, also register the bson mime type format:

```ruby
# config/initializers/mime_types.rb
Mime::Type.register "application/bson", :bson
```

One can additionally use a custom BSON implementation by setting the Rabl `bson_engine` configuration attribute.
This custom BSON engine must conform to the BSON#serialize method signature.

```ruby
class CustomEncodeEngine
  def self.serialize string
    # Custom Encoding by your own engine.
  end
end

Rabl.configure do |config|
  config.bson_engine = CustomEncodeEngine
end
```

*NOTE*: Attempting to render the bson format without either including the bson gem or
setting a `bson_engine` will cause an exception to be raised.

### Plist ###

Rabl also includes optional support for [Plist](http://developer.apple.com/library/mac/#documentation/Cocoa/Conceptual/PropertyLists/Introduction/Introduction.html]) serialization format using the [plist gem](http://plist.rubyforge.org/).
To enable, include the plist gem in your project's Gemfile. Then use Rabl as normal with the `plist` format (akin to other formats).

```ruby
# Gemfile
gem 'plist'
```

There is also an option for a custom Plist implementation by setting the Rabl `plist_engine` configuration attribute.

```ruby
class CustomEncodeEngine
  def self.dump string
    # Custom Encoding by your own engine.
  end
end

Rabl.configure do |config|
  config.plist_engine = CustomEncodeEngine
end
```

*NOTE*: Attempting to render the plist format without either including the plist gem or setting a `plist_engine` will cause an exception to be raised.

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

or specify a root node label for the collection:

```ruby
collection @users => :people
# => { "people" : [ { "person" : { ... } } ] }
```

or even specify both the child and root labels for a collection:

```ruby
collection @users, :root => "people", :object_root => "user"
# => { "people" : [ { "user" : { ... } } ] }
```

and this will be used as the default data for the rendering, or disable the object root explicitly:

```ruby
collection @users, :root => "people", :object_root => false
# => { "people" : [ { ... }, { ... } ] }
```

There can also be odd cases where the root-level of the response doesn't map directly to any object:

```ruby
object false
node(:some_count) { |m| @user.posts.count }
child(@user) { attribute :name }
```

In those cases, object can be assigned to 'false' and nodes can be constructed free-form.

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

This will generate a json response based on the result of the `node` block:

```ruby
# app/views/users/show.json.rabl
node :full_name do |u|
  u.first_name + " " + u.last_name
end
```

or a custom node that exists only if a condition is true:

```ruby
# m is the object being rendered, also supports :unless
node(:foo, :if => lambda { |m| m.has_foo? }) do |m|
  m.foo
end
```

or don't pass a name and have the node block merged into the response:

```ruby
node do |u|
  { :full_name => u.first_name + " " + u.last_name }
  # => { full_name : "Bob Johnson" }
end
```

You can use custom nodes like these to create flexible representations of a value utilizing all the data from the model.

### Partials ###

Often you need to access other data objects in order to construct custom nodes in more complex associations. You can get access to the rabl representation of another data object by rendering a RABL partial:

```ruby
node :location do
  { :city => @city, :address => partial("users/address", :object => @address) }
end
```

or event access an object associated with the parent model:

```ruby
node :location do |m|
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

node :can_drink do |m|
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

### Template Scope ###

In RABL, you have access to everything you need to build an API response. Each RABL template has full access to the controllers
instance variables as well as all view helpers and routing urls.

```ruby
# app/some/template.rabl
object @post
# Access instance variables
child(@user => :user) { ... }
# or Rails helpers
node(:formatted_body) { |post| simple_format(post.body) }
```

There should be no problem fetching the appropriate data to construct a response.

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

### Caching ###

Caching works by saving the entire template output to the configured cache_store in your application. Note that caching is currently **only available** for
Rails but support for other frameworks is planned in a future release. 

For Rails, requires `action_controller.perform_caching` to be set to true in your environment, and for `cache` to be set to a key (object that responds to cache_key method, array or string).

```ruby
# app/views/users/show.json.rabl
object @quiz
cache @quiz # key = rabl/quiz/[cache_key]
attribute :title
```

The `cache` keyword accepts the same parameters as fragment caching for Rails.

```ruby
cache @user            # calls @user.cache_key
cache ['keel', @user]  # calls @user.cache_key and prefixes with kewl/
cache 'lists'          # explicit key of 'lists'
cache 'lists', expires_in: 1.hour
```

The cache keyword is used from within the base template. It will ignore any cache keys specified in an extended template or within partials.

```ruby
# app/views/users/index.json.rabl
collection @users
cache @users  # key = rabl/users/[cache_key]/users/[cache_key]/...

extends "users/show"
```

and within the inherited template:

```ruby
# app/views/users/show.json.rabl
object @user
cache @user # will be ignored

attributes :name, :email
```
Caching can significantly speed up the rendering of RABL templates in production and is strongly recommended when possible.

### Content Type Assignment ###

Currently in RABL, the content-type of your response is not set automatically. This is because RABL is intended
to work for any Rack-based framework and as agostic to format as possible.
Check [this issue](https://github.com/nesquena/rabl/issues/185#issuecomment-4501232) for more
details, and if you have any ideas or patches please let me know.

In the meantime, be sure to set the proper content-types if needed. This is usually pretty simple in both
Rails and Padrino. I recommend a before_filter on that controller or directly specified in an action.

## Resources ##

There are many resources available relating to RABL including the [RABL Wiki](https://github.com/nesquena/rabl/wiki),
and many tutorials and guides detailed below.

### Advanced Usage ###

Links to resources for advanced usage:

 * Rendering JSON for a tree structure using RABL: https://github.com/nesquena/rabl/issues/70
 * Layouts (erb, haml and rabl) in RABL: https://github.com/nesquena/rabl/wiki/Using-Layouts
 * Backbone or [Ember.js](http://www.emberjs.com) Integration: https://github.com/nesquena/rabl/wiki/Backbone-Integration

Please add your own usages and let me know so we can add them here! Also be sure to check out
the [RABL Wiki](https://github.com/nesquena/rabl/wiki) for other usages.

### Tutorials ###

Tutorials can always be helpful when first getting started:

 * [Railscasts #322](http://railscasts.com/episodes/322-rabl)
 * http://blog.joshsoftware.com/2011/12/23/designing-rails-api-using-rabl-and-devise/
 * http://engineering.gomiso.com/2011/06/27/building-a-platform-api-on-rails/
 * http://blog.lawrencenorton.com/better-json-requests-with-rabl
 * http://www.rodrigoalvesvieira.com/developing-json-api-rails-rabl/
 * http://tech.favoritemedium.com/2011/06/using-rabl-in-rails-json-web-api.html
 * http://seesparkbox.com/foundry/better_rails_apis_with_rabl
 * http://blog.dcxn.com/2011/06/22/rails-json-templates-through-rabl
 * http://teohm.github.com/blog/2011/05/31/using-rabl-in-rails-json-web-api

Let me know if there's any other useful resources not listed here.

### Related Libraries ###

There are several libraries that either complement or extend the functionality of RABL:

 * [grape-rabl](https://github.com/LTe/grape-rabl) - Allows rabl templates to be used with [grape](https://github.com/intridea/grape)
 * [gon](https://github.com/gazay/gon) - Exposes your Rails variables in JS with RABL support integrated.

Let me know if there's any other related libraries not listed here.

### Troubleshooting ###

 * Redundant calls for a collection: https://github.com/nesquena/rabl/issues/142#issuecomment-2969107
 * Testing RABL Views: https://github.com/nesquena/rabl/issues/130#issuecomment-4179285

### Examples ###

See the [examples](https://github.com/nesquena/rabl/tree/master/examples) directory.

## Issues ##

Check out the [Issues](https://github.com/nesquena/rabl/issues) tab for a full list:

 * Better Tilt template support (precompiling templates)
 * Benchmarks and performance optimizations

## Continuous Integration ##

[![Continuous Integration status](https://secure.travis-ci.org/nesquena/rabl.png)](http://travis-ci.org/nesquena/rabl)

CI is hosted by [travis-ci.org](http://travis-ci.org).

## Authors and Contributors ##

Thanks to [Miso](http://gomiso.com) for allowing me to create this for our applications and release this project!

* [Nathan Esquenazi](https://github.com/nesquena) - Creator of the project
* [Arthur Chiu](https://github.com/achiu) - Core Maintainer, Riot Testing Guru
* [Tim Lee](https://github.com/timothy1ee) - RABL is an awesome name and was chosen by the Miso CTO.
* [Rick Thomas](https://github.com/rickthomasjr) - Added options for extends and Sinatra testing
* [Benjamin Yu](https://github.com/byu) - Added msgpack format support
* [Chris Kimpton](https://github.com/kimptoc) - Helping with documentation and wiki
* [Marjun](https://github.com/mpagalan) - Added xml option configurations
* [Anton Orel](https://github.com/skyeagle) - Added Rails 3.1 compatibility
* [Sasha Koss](https://github.com/kossnocorp) - Added multi_json support
* [Matthew Schulkind](https://github.com/mschulkind) - Cleanup of configuration and tests
* [Luke van der Hoeven](https://github.com/plukevdh) - Support non-ORM objects in templates
* [Andrey Voronkov](https://github.com/Antiarchitect) - Added BSON format support
* [Alli Witheford](https://github.com/alzeih) - Added Plist format support
* [David Sommers](https://github.com/databyte) - Added template caching support for Rails

and many more contributors listed in the [CHANGELOG](https://github.com/nesquena/rabl/blob/master/CHANGELOG.md).

Want to contribute support for another format?
Check out the patches for [msgpack support](https://github.com/nesquena/rabl/pull/69), [plist support](https://github.com/nesquena/rabl/pull/153) and
[BSON support](https://github.com/nesquena/rabl/pull/163) for reference.

Please fork and contribute, any help in making this project better is appreciated!

## Inspirations ##

There are a few excellent libraries that helped inspire RABL and they are listed below:

 * [Tequila](https://github.com/inem/tequila)
 * [JSON Builder](https://github.com/dewski/json_builder)
 * [Argonaut](https://github.com/jbr/argonaut)

Thanks again for all of these great projects.

## Copyright ##

Copyright © 2011-2012 Nathan Esquenazi. See [MIT-LICENSE](https://github.com/nesquena/rabl/blob/master/MIT-LICENSE) for details.
