# frozen_string_literal: true

$:.push File.expand_path("../lib", __FILE__)
require "rabl/version"

Gem::Specification.new do |s|
  s.name        = "rabl"
  s.version     = Rabl::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Nathan Esquenazi"]
  s.email       = ["nesquena@gmail.com"]
  s.homepage    = "https://github.com/nesquena/rabl"
  s.summary     = %q{General ruby templating with json, bson, xml and msgpack support}
  s.description = %q{General ruby templating with json, bson, xml and msgpack support}
  s.license     = 'MIT'

  s.files         = `git ls-files -z -- {*.md,MIT-LICENSE,lib}`.split("\x0").sort
  s.require_paths = ["lib"]


  if RUBY_VERSION < "1.9"
    s.add_dependency 'activesupport', '>= 2.3.14', '<= 4'
  else
    s.add_dependency "activesupport", '>= 2.3.14'
  end
end
