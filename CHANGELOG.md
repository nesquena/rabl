# CHANGELOG

## 0.6.2

  * Adds template caching support for Rails (Thanks @databyte)

## 0.6.1

  * Upgrade dependency to multi_json 1.1.0 (Thanks @geronimo)

## 0.6.0

 * Change engine to only instantiate one builder when rendering a collection
 * Alias to\_msgpack to to\_mpac
 * Cache template sources for faster partial lookups (thanks @cj)
 * Adds BSON format support (thanks @Antiarchitect)
 * Use template lookup mechanism to find templates in Rails 3 (thanks @blakewatters)
 * Adds a 'object_root' option to collection (thanks @blakewatters)
 * Adds a 'root_name' option to collection
 * Adds PList format support (thanks @alzeih)
 * Fixes infinite recursion in edge case calculating object root name
 * Fixes issue with nameless node that has an array result
 * Adds support for `object_root => false` (Thanks @Lytol)

## 0.5.4

 * Ensure ActionView is defined before registering Rails template handler (thanks cj)

## 0.5.2-0.5.3

 * Add better support for conditionals for child (thanks gregory)
 * Fix issue introduced with 'node' and properly clear options (thanks joshbuddy)

## 0.5.1

 * Use respond\_to? instead of checking Enumerable for is\_object
 * Performance optimization (thanks Eric Allen)

## 0.5.0

 * Adds comprehensive fixture suite (padrino,rails2,rails3,sinatra)
 * Travis CI Integration Testing
 * Cleanup json configuration and related tests (Thanks mschulkind)
 * Adds CHANGELOG to track changes
 * Adds optional MessagePack format support (thanks byu)
 * Explicit requires for ActiveSupport now in gemspec and lib
 * Adds template support for regular (non-ORM) ruby objects (thanks plukevdh)
 * Fixes bug with the child root not properly appearing in all cases
 * Better stack traces by tracking source location in instance_eval (thanks skade)
 * Fix issue with controller object detection failing in namespaces (thanks alunny)
 * Fix ruby -w warnings (thanks achiu)
 * Better partial implementation which passes options
 * Better fetch_source implementation for Padrino (thanks skade)
 * Better fetch_source implementation for Rails
 * Added fetch_source implementation for Sinatra
 * Lots of test refactorings / cleanup / improvement
 * Code block name is now optional [Thanks brentmurphy]

## 0.3.0

 * Use multi_json to handle JSON encoding (Thanks kossnocorp)
 * Fixes unit tests with hash order on 1.8.7

## 0.2.8

 * Fixes Rails 3.1 Compatibility (Thanks skyeagle)
 * Fixes Ruby 1.8.6 Compatibility (Thanks Don)
 * Adds much better riot unit testing (Thanks Achiu)
