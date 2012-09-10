# RABL #

[![Continuous Integration status](https://secure.travis-ci.org/nesquena/rabl.png)](http://travis-ci.org/nesquena/rabl)
[![Dependency Status](https://gemnasium.com/nesquena/rabl.png)](https://gemnasium.com/nesquena/rabl)

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

## Breaking Changes ##

 * v0.6.14 (released June 28, 2012) requires the use of render_views
   with RSpec to test templates. Otherwise, the controller will simply
   pass through the render command as it does with ERB templates.

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

**Important:** With Padrino, be sure that **the rabl gem is listed after the padrino gem in your Gemfile**, otherwise
Rabl will not register properly as a template engine.

With Sinatra, or any other tilt-based framework, simply register:

```ruby
Rabl.register!
```

and RABL will be initialized and ready for use. For usage with Sinatra, check out
the [Sinatra Usage](https://github.com/nesquena/rabl/wiki/Setup-for-Sinatra) guide.

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

```js
[{  "post" :
  {
    "id" : 5, title: "...", subject: "...",
    "user" : { full_name : "..." },
    "read" : true
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
  # config.cache_sources = Rails.env != 'development' # Defaults to false
  # config.cache_engine = Rabl::CacheEngine.new # Defaults to Rails cache
  # config.escape_all_output = false
  # config.json_engine = nil # Any multi_json engines or a Class with #encode method
  # config.msgpack_engine = nil # Defaults to ::MessagePack
  # config.bson_engine = nil # Defaults to ::BSON
  # config.plist_engine = nil # Defaults to ::Plist::Emit
  # config.include_json_root = true
  # config.include_msgpack_root = true
  # config.include_bson_root = true
  # config.include_plist_root = true
  # config.include_xml_root  = false
  # config.include_child_root = true
  # config.enable_json_callbacks = false
  # config.xml_options = { :dasherize  => true, :skip_types => false }
  # config.view_paths = []
end
```

Each option specifies behavior related to RABL's output. If `include_json_root` is disabled that removes the
root node for each root object in the output, and `enable_json_callbacks` enables support for 'jsonp' style callback
output if the incoming request has a 'callback' parameter.

If `include_child_root` is set to false then child objects in the response will not include
a root node by default. This allows you to further fine-tune your desired response structure.

If `cache_engine` is set, you should assign it to a class with a `fetch` method. See the [default engine](https://github.com/nesquena/rabl/blob/master/lib/rabl/cache_engine.rb) for an example.

If `cache_sources` is set to `true`, template lookups will be cached for improved performance.
The cache can be reset manually by running `Rabl.reset_source_cache!` within your application.

If `cache_all_output` is set to `true`, every template including each individual template used as part of a collection will be cached separately.
Additionally, anything within child, glue and partial will also be cached separately.
To cache just a single template, see the section titled 'Caching' below.

If `escape_all_output` is set to `true` and ActiveSupport is available, attribute output will be escaped using [ERB::Util.html_escape](http://corelib.rubyonrails.org/classes/ERB/Util.html).
Custom nodes will not be escaped, use `ERB::Util.h(value)`.

If `view_paths` is set to a path, this view path will be checked for every rabl template within your application.
Add to this path especially when including Rabl in an engine and using view paths within a another Rails app.

Note that the `json_engine` option uses [multi_json](http://intridea.com/2010/6/14/multi-json-the-swappable-json-handler) engine
defaults so that in most cases you **don't need to configure this** directly. For example, if you wish to use yajl as
the primary JSON encoding engine simply add that to your Gemfile:

```ruby
# Gemfile
gem 'yajl-ruby', :require => "yajl"
```

and RABL will automatically start using that engine for encoding your JSON responses!

To use RABL with JSON engine not supported by `multi_json`, ensure that JSON engine
supports `encode` method and set `json_engine` option to the engine's Class name:

```ruby
config.json_engine = ActiveSupport::JSON
```

### Format Configuration ###

RABL supports configuration for MessagePack, BSON, and Plist. Check the
[Format Configuration](https://github.com/nesquena/rabl/wiki/Configuring-Formats) page for more details.

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

Named and aliased attributes can not be combined on the same line. This currently does not work:

```ruby
attributes :foo, :bar => :baz # throws exception
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

You can also pass in the current object:

```ruby
object @user
child :posts do |user|
  attribute :title unless user.suspended?
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

You can also pass in the current object:

```ruby
object @user
glue(@post) {|user| attribute :title if user.active? }
```

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

or even access an object associated with the parent model:

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

You can see more examples on the [Reusing Templates wiki page](https://github.com/nesquena/rabl/wiki/Reusing-templates).

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

RABL has built-in caching support for templates leveraging fragment caching strategies. Note that caching is currently **only available** for Rails but support for other frameworks is planned in a future release. Simplest caching usage is:

```ruby
# app/views/users/show.json.rabl
object @quiz
cache @quiz # key = rabl/quiz/[cache_key]
attribute :title
```

Caching can significantly speed up the rendering of RABL templates in production and is strongly recommended when possible. For more a more detailed look at caching, check out the [Caching](https://github.com/nesquena/rabl/wiki/Caching-in-RABL) guide on the wiki.

### Rendering Templates Directly ###

There are situations where an application requires RABL templates to be rendered outside
a traditional view context. For instance, to render RABL within a Rake task or to create
message queue payloads. For this case, `Rabl.render` can be used as show below:

```ruby
Rabl.render(object, template, :view_path => 'app/views', :format => :json) #=> "{...json...}"
```

You can use convenience methods on `Rabl::Renderer` to render the objects as well:

```ruby
Rabl::Renderer.json(@post, 'posts/show')
Rabl::Renderer.xml(@post, 'posts/show')
```

These methods allow RABL to be used for arbitrary conversions of an object into a desired format.

```ruby
Rabl::Renderer.new('posts/show', @post, :view_path => 'app/views', :format => 'hash').render
```

You can also pass in other instance variables to be used in your template as:

```ruby
Rabl::Renderer.new('posts/show', @post, :locals => { :custom_title => "Hello world!" })
````

Then, in your template, you can use `@custom_title` as:

```
attribute :content
node(:title) { @custom_title }
```

### Content Type Headers ###

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

 * Grape Integration: https://github.com/nesquena/rabl/wiki/Using-Rabl-with-Grape
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

There are other libraries that can either complement or extend the functionality of RABL:

 * [gon](https://github.com/gazay/gon) - Exposes your Rails variables in JS with RABL support integrated.

Let me know if there's any other related libraries not listed here.

### Troubleshooting ###

 * Redundant calls for a collection: https://github.com/nesquena/rabl/issues/142#issuecomment-2969107
 * Testing RABL Views: https://github.com/nesquena/rabl/issues/130#issuecomment-4179285

### Examples ###

See the [examples](https://github.com/nesquena/rabl/tree/master/examples) directory.

## Issues ##

Check out the [Issues](https://github.com/nesquena/rabl/issues) tab for a full list:

 * Rigorous benchmarking and performance optimizations

## Authors and Contributors ##

Thanks to [Miso](http://gomiso.com) for allowing me to create this for our applications and release this project!

* [Nathan Esquenazi](https://github.com/nesquena) - Creator of the project
* [Arthur Chiu](https://github.com/achiu) - Core Maintainer, Riot Testing Guru
* [Tim Lee](https://github.com/timothy1ee) - RABL was a great name chosen by the Miso CTO.
* [David Sommers](https://github.com/databyte) - Template resolution, caching support, and much more
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
* [Ryan Bigg](https://github.com/radar) - Improved template resolution code
* [Ivan Vanderbyl](https://github.com/ivanvanderbyl) - Added general purpose renderer
* [Cyril Mougel](https://github.com/shingara) - Added cache_engine pluggable support and renderer tweaks
* [Teng Siong Ong](https://github.com/siong1987) - Improved renderer interface
* [Brad Dunbar](https://github.com/braddunbar) - Pass current object into blocks

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

