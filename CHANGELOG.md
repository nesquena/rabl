# CHANGELOG

## 0.8.4

 * NEW #411 Add "replace nil values with empty strings" option (Thanks @manuelmeurer)

## 0.8.3

 * Closes #421 bug with locals in engine

## 0.8.2

 * Passing locals when rendering templates via partials or inheritance (Thanks @simsalabim)

## 0.8.1

 * Fix to respect @collection :root for xml output (Thanks @chinshr)

## 0.8.0

 * Remove multi_json dependency, simpler JSON handling

## 0.7.10

 * Add early support for Rails 4 (Thanks @jopotts)
 * Add configuration option for raising on missing attributes (Thanks @ReneB)
 * Allow caching outside the Rails environment (Thanks @flyerhzm)
 * Fix template lookup on Rails (Thanks @vimutter)

## 0.7.9

 * Replace yajl with oj in docs and tests
 * Fix handling of empty children arrays with tests (Thanks @sethvargo)

## 0.7.8

  * Additional fix for attribute conditional support

## 0.7.7

  * Fix #344 to avoid: "warning: default `to_a' will be obsolete"
  * Fix #356 by adding 'known object classes' like struct to be recognized as objects.
  * Fix #354 by adding 'if' and 'unless' to `attribute` (Thanks @andrewhubbs)

## 0.7.6

  * Fix render behavior by separating data_object and data_name in engine
  * Fix regression with 'child' behavior with nil on extends (with tests)

## 0.7.5

  * Avoid incorrectly setting implicit objects for 'object false' partials

## 0.7.4

  * Fix issue #347 with extends failing for custom object templates

## 0.7.3

  * Fix issue #342 with nil case for format checking in engine `request_params`

## 0.7.2

  * Set instance variables for locals in engine instead of renderer (Thanks @geehsien)
  * Changes default JSON engine for Rails, move logic to separate class (Thanks @shmeltex)

## 0.7.1

  * Improved renderer interface (Thanks @siong1987)
  * Pass current object into blocks (Thanks @braddunbar)

## 0.7.0

  * Use source_format when looking up partials (Thanks @databyte)
  * Add README note about render_views (Thanks @databyte)
  * Add support for Rails 3.2+ sending custom mime types (Thanks @databyte)
  * Add option to define his own cache_engine (Thanks @shingara)

## 0.6.14

  * Fix RSpec under Rails 3, use render_views to test output (Thanks @agibralter)
  * Fix extends allows passing in local object when root object is specified

## 0.6.13

  * Small tweak to is_collection detection (look for each and map)
  * Adds `include_child_root` configuration option (Thanks @yoon)

## 0.6.12

  * Fix view_path options for renderer (Thanks @ivanvanderbyl and @route)
  * Only escape if data exists
  * Fix default object recognition for Rails 2.3.2
  * Adds `root_object` method on engine (Thanks @OliverLetterer)

## 0.6.11

  * Changes send to __send__ (Thanks @alindeman)
  * Change object/collection checks to :map instead of :each
  * Adds support for auto-escaping attribute configuration (Thanks @databyte)
  * Adds support for configuration of view_paths (Thanks @ivanvanderbyl)
  * Fix issue with helpers caching check

## 0.6.10

  * Fixes expected behavior with nil and collection keyword
  * Fixes multi_json to support newer form syntax (Thanks @rajatvig)

## 0.6.9

  * Adds support for generic template rendering (Thanks @ivanvanderbyl)
  * Allow cache to be called with an explicit key (Thanks @databyte)

## 0.6.8

  * Fix Rails 3 resolution on Ruby < 1.9.2

## 0.6.7

  * Fix format to default to json in the event that it is a 'hash' (Thanks @databyte)
  * Support using cache keys within extended templates (Thanks @databyte)

## 0.6.6

  * Even more improvements to Rails template resolution (Thanks @databyte)
  * Added fixture integration tests for rendering rabl inline from html (Thanks @databyte)
  * Added useful note to README about Padrino (Thanks @simonc)

## 0.6.5

  * Fixed issue with multi_json version use ~> 1.0 (Thanks @sferik)

## 0.6.4

 * Further improvements to template path resolution for Rails (Thanks @radar)
 * Change multi_json to be > 1.1.0 to support 1.2.0 with Oj support (Thanks @jherdman)

## 0.6.3

 * Adds Rails 3.2 Integration Test
 * Much improved Rails template path resolution

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
