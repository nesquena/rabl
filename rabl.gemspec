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
  s.summary     = %q{Ruby templating system for generating JSON, XML, MessagePack, PList, and BSON}
  s.license     = 'MIT'

  s.files         = `git ls-files -z -- {*.md,MIT-LICENSE,lib}`.split("\x0").sort
  s.require_paths = ["lib"]

  s.metadata['bug_tracker_uri'] = 'https://github.com/nesquena/rabl/issues'
  s.metadata['changelog_uri'] = 'https://github.com/nesquena/rabl/blob/master/CHANGELOG.md'
  s.metadata['source_code_uri'] = 'https://github.com/nesquena/rabl'

  if RUBY_VERSION < "1.9"
    s.add_dependency 'activesupport', '>= 2.3.14', '<= 4'
  else
    s.add_dependency 'activesupport', '>= 2.3.14', '< 7'
  end

  s.add_development_dependency 'riot',    '~> 0.12.7'
  s.add_development_dependency 'rr',      '~> 1.2'
  s.add_development_dependency 'rake',    '>= 12', '< 14'
  s.add_development_dependency 'tilt',    '~> 2.0'
  s.add_development_dependency 'oj',      '~> 3.3'
  s.add_development_dependency 'msgpack', '~> 1.3'
  s.add_development_dependency 'bson',    '~> 1.12'
  s.add_development_dependency 'plist',   '~> 3.5'
end
