# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "rabl/version"

Gem::Specification.new do |s|
  s.name        = "rabl"
  s.version     = Rabl::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Nathan Esquenazi"]
  s.email       = ["nesquena@gmail.com"]
  s.homepage    = "https://github.com/nesquena/rabl"
  s.summary     = %q{General ruby templating for json or xml}
  s.description = %q{General ruby templating for json or xml}

  s.rubyforge_project = "rabl"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'multi_json', '~> 1.0.3'

  s.add_development_dependency 'riot', '~>0.12.3'
  s.add_development_dependency 'rr', '~>1.0.2'
  s.add_development_dependency 'mongoid'
  s.add_development_dependency 'tilt'
  s.add_development_dependency 'bson_ext'
  s.add_development_dependency 'yajl-ruby'
end
