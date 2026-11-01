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
  s.summary     = %q{General ruby templating with json, bson, xml and msgpack support}
  s.description = %q{General ruby templating with json, bson, xml and msgpack support}
  s.license     = 'MIT'
  s.metadata    = {
    "changelog_uri"         => "https://github.com/nesquena/rabl/blob/master/CHANGELOG.md",
    "source_code_uri"       => "https://github.com/nesquena/rabl",
    "bug_tracker_uri"       => "https://github.com/nesquena/rabl/issues",
    "rubygems_mfa_required" => "true"
  }

  s.files         = `git ls-files -z`.split("\x0").grep(%r{\A(?:[^./][^/]*\.md|MIT-LICENSE|lib/.+)\z}).sort
  s.require_paths = ["lib"]
  s.required_ruby_version = '>= 2.7'

  s.add_dependency "activesupport", '>= 6.1'
end
