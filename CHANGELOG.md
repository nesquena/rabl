# CHANGELOG

## 0.18.0 (unreleased)

* Require Ruby 2.7 or newer. rabl hasn't loaded on Ruby 1.9 since 0.16.0, and 2.0–2.6 are long past end of life (@nesquena)
* Allow BSON >= 2.0 (@tagliala)
* Support Frozen String Literals (@tagliala)
* Fix extract_options! not being available (@A1bi)
* Improve caching lookup performance (@pharris2411)
* `child :name` on a collection is now keyed by the name you wrote, the same as `child :name => :name`. Before, rabl used the relation's table name or the first item's class, so `child :units` on `has_many :units, through: ..., source: :product_unit` rendered `"product_units": [{"product_unit": ...}]` and two associations on one table overwrote each other. Existing apps whose association or method name differs from its table or item class get the new key and item root (`"units": [{"unit": ...}]`); item roots are the singular of the name you wrote (`child :data` gives `"data": [{"datum": ...}]`), and with `:root => :other` the key is `other` while items are still named after the symbol (`child :favorites, :root => :likes` gives `"likes": [{"favorite": ...}]`). `child @collection` without a name is unchanged (#394, reported by @jifka)
* `child @items, :root => :name` now keeps its key when `@items` is empty or nil, rendering `"name": []` or `"name": null` (`<name type="array"/>` or `<name nil="true"/>` in XML), the same as `child @items => :name`. Before, the key was left out; existing apps using the `:root` form will see the new key for empty or nil data. Other blank data (`false`, `""`) and a false `:if`/`:unless` still leave it out (#725, reported by @Kinaan)
* XML: a collection with an explicit `:object_root` now wraps each item once, in the object root. `collection @categories, :root => "data", :object_root => "category"` rendered `<data type="array"><datum><category>...</category></datum></data>` and now renders `<data type="array"><category>...</category></data>`. Existing XML clients of such collections lose the extra element; JSON output and collections without `:object_root` are unchanged (#581, reported by @jeffleeismyhero)
* With Oj 3.17.7 or newer, `require 'rabl'` no longer overwrites Oj options the app has already set. If `Oj.default_options` still has Oj's shipped `mode`, `time_format` and `use_to_json` when rabl is loaded, rabl sets them globally as before (`mode: :compat, time_format: :ruby, use_to_json: true`); if the app (or a library loaded earlier) already chose any of them, they are left alone, and rabl passes `Oj.dump` only the options that differ from Oj's global ones, so rabl's JSON is unchanged. Options the app changes after loading rabl still apply to rabl's output as before: `time_format`, `use_to_json`, and `mode` when it is `:compat`, `:rails` (which escapes `<`, `>` and `&`) or `:custom`; a `:strict`, `:null` or `:object` mode set after loading rabl no longer makes rabl's JSON raise or drop values (it stays `:compat`). What changes for apps on Oj 3.17.7+ that set Oj options before loading rabl: their own `Oj.dump` calls, and a custom `config.json_engine` that calls `Oj.dump(obj)` without options, now use the app's options instead of rabl's (pass `Rabl.configuration.oj_dump_options`, or use `config.json_engine = Oj`, to get rabl's). With older Oj, behaviour is unchanged: rabl sets its options globally at load and calls `Oj.dump(obj)`, because Oj before 3.17.7 passes per-call options on to `to_json`, which json 3.x rejects (#744, reported by @BuonOmo)
* `extends` on a collection of plain Hashes now renders each Hash's own values. Before, the item handed to the extended template was re-read as rabl's `@object => :name` syntax (one key) or as a collection (several keys), so `collection @friends` + `extends 'friends/show'` rendered `[{"uid":"uid"}]` or `[{}]`, or raised. Existing apps rendering Hash items through `extends` get the real values instead of that output; the alias syntax in `object`, `collection`, `child`, `glue` and an explicit `:object` option to `extends` or `partial` is unchanged. Unchanged too: an unnamed `collection @hashes` still takes its item root from the first Hash (name it, e.g. `collection @friends => :friends`) (#396, reported by @ericgross)
* README: `camelize_keys` applies to the attribute, node and child names rabl builds, not to root names or to keys inside a hash a `node` block returns; documents the `deep_transform_keys` workaround. No behaviour change (#701, reported by @apuntovanini)
* Fix cached `child` nodes in a collection being flattened (or dropped, for a child collection) on a cache hit (@nesquena)
* Fix caching outside Rails: rendering a cached collection raised `LocalJumpError`, and cached collection fragments were never read back (@nesquena)
* Fix `escape_all_output` changing the app's own arrays and hashes in place (and re-escaping cached fragments outside Rails on every render), raising `FrozenError` on frozen values, and raising `NameError` for `ERB` outside Rails (@nesquena)

## 0.17.0 (Nov 26, 2024)

* Support for Rails 8 (@basex)

## 0.16.1 (Oct 10, 2022)

* Fix ArgumentError when there are no keyword arguments for Ruby < 2.7 (Thanks @sylvain-8422)

## 0.16.0 (August 21, 2022)

* Add "except" option to `extends` (Thanks @perryqh)
* Fix `ArgumentError` when block given with keyword arguments (Thanks @kyoshidajp)
* Add Ruby 3.1 to the CI matrix (Thanks @petergoldstein)
* Document Rabl setting `oj`'s mode (Thanks @ghiculescu)

## 0.15.0 (December 30, 2021)

* Support for Rails 7 (@tagliala)
* Improvements to unit testing
* Miscellaneous other bug fixes

## 0.14.5 (May 29th, 2021)

* Restrict and validate the `to_***` methods available within engine (Brian McFadden)

## 0.14.4 (April 1st, 2021)

* Test against latest Ruby versions
* Exclude yarn lock
* Remove non-required files from the .gem

## 0.14.3 (April 22nd, 2020)

* Fix regression on Rails 4.2 (@tagliala)

## 0.14.2 (September 10th, 2019)

* Made Rails 6 compatible (@jpawlyn)
* Drop EOL'd property from gemspec (@olleolleolle)

## 0.14.1 (April 28th, 2019)

* Many adjustments and various non-breaking fixes
* Improvements to caching (@zenspider)
* Fix tests for Rails 5 (@robertoz)

## 0.13.1 (October 21st, 2016)

* Further compatibility with Rails 5

## 0.13.0 (July 15th, 2016)

* Compatibility with Rails 5

## 0.12.0 (February 13th, 2016)

* Compatibility with ruby 2.3.0 (@vmeyet)

## 0.11.8 (January 10th, 2016)

* Check that the Rails module has the .version method before invocation (@caldwecr)
* Adds nominal rails5 support (@lsylvester)

## 0.11.7 (December 6th, 2015)

* Use empty hash as default cache options (@infertux)
* Update ERB::Util link in README (@mortonfox)

## 0.11.6 (January 26th)

* Fix resolve_condition and simplify call_condition_proc (@vmeyet)
* Respect eagerly loaded collections by not always calling #to_ary (@DouweM)
* Move creation of options and engine in tilt template to avoid threading issues (@jseriff)

## 0.11.5 (December 5th)

* Check if context_scope includes ".settings.views" for Sinatra (@LTe)
* Fix view path issue for partials (@LTe)

## 0.11.4 (November 7th)

* FIX Get MultiBuilder to behave properly around nil engines (@DouweM)

## 0.11.3 (November 3rd)

* FIX error when attempting to cache empty child collections (@DouweM)
* FIX bug causing Rails 4 cache digests never to be appended (@DouweM)

## 0.11.2 (October 26th)

* FIX Don't put nil into builder engines when glueing nil object (@DouweM)

## 0.11.1 (October 19th)

* NEW #417 Major rewrite caching layer to be much faster using read_multi (@ahlatimer, @DouweM)
* FIX #589 Use set to speed up is_collection method check (@ccocchi)
* FIX #584 Fix issues with newer releases of oj gem (@DouweM)

## 0.11.0 (August 16th)

* Restore ruby 1.8 compatibility (@s01ipsist, @patrickdavey)
* Fix Rabl::Tracker to match paths with numbers (@szimek)
* Fix caching of a recursive template (@bonobos)
* Fix cache for non-rails apps (@t-k)
* Escape output all at once to properly escape content (@bholzer)
* Add hashie mash to known object list (@nguyenmighty)
* Remove root object when set to false value (@mrThe)

## 0.10.1 (May 28th)

* Fix nasty formatting bug that broke XML (@bhicks)

## 0.10.0 (May 24th)

* Fix typo in readme about new options (@PikachuEXE)
* Use the request format for source lookup (@omgitsads)
* Simplify rendering methods with refactor (@bhicks)
* Reset format and scope options for each request (@bhicks)
* Convert keys to ensure uniqueness (@swalkinshaw)
* Add fallback for child name if its nil (@swalkinshaw)
* Apply replace_xxx_values recursively within nested values (@igas)

## 0.9.4.pre1 (March 30th)

* NEW #527 Add configuration excluding empty values in collections (@addbrick)
* FIX #516 Set default root_object lazily (@DouweM)
* FIX #540 Fix cache digest in Rails 4.1 (@huoxito)
* FIX #534 Bug with management of empty string values (@nickkov89)
* FIX #519 JSON in README (@shirish4you)
* NEW #514 Add configuration to exclude nil values (@oharsta)

## 0.9.3 (December 5th)

* FIX Send engine options through from render call (Thanks @bhicks)
* FIX Cleanup compile_hash method through refactoring complexity (Thanks @bhicks)
* FIX #503 handling render case with no lookup_context in Rails 4
* FIX #502 fix regression in render when object is nil with explicit root name

## 0.9.2 (November 21 2013)

* FIX #508 by avoiding new proc syntax breaking 1.8.7

## 0.9.1 (November 17 2013)

* NEW #507 Resolve conditionals for extends (Thanks @micahcraig)
* NEW #453 Support for symbol conditionals (Thanks @leoc)

## 0.9.0 (October 14 2013)

* FIX #497 Renderer should support partial caching and a digestor bug fixed (Thanks @siong1987)

## 0.9.0.pre3 (Sept 22 2013)

 * FIX #495 Digest cache when rendering from controller (Thanks @siong1987)

## 0.9.0.pre2 (Sept 02 2013)

 * FIX #142 Better resource resolution for AR Scopes
 * Adds Rails 4 test fixture   (Thanks @siong1987)
 * Adds Rails 4 cache digestor (Thanks @siong1987)
 * Child now supports `object_root` and `root` arguments like 'collection'
 * FIX #486 Prioritize to_hash options to allow setting root

## 0.8.6

 * FIX #142 #467 Do not use a collection as the default object. (Thanks @mrbrdo)
 * NEW Options hash for glue function added (Thanks @sassysolutions)
 * FIX #470 Better template lookups when Padrino is defined (Thanks @LTe)

## 0.8.5

 * FIX #386 Support disabling root on child calls (Thanks @digger69)

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
