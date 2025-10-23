source 'https://rubygems.org'

# Specify your gem's dependencies in rabl.gemspec
gemspec

gem 'i18n', '>= 0.6'

platforms :mri_18 do
  gem 'SystemTimer'
  gem 'json'
end

group :test do
  # RABL TEST
  gem 'builder'

  rails_version = RUBY_VERSION =~ /\A(1|2.[01])/ ? '~> 4.0' : '>= 4.0'
  sqlite3_version = RUBY_VERSION >= '2.5' ? '>= 1.5' : '< 1.5'
  # FIXTURES
  gem 'rack-test', :require => 'rack/test'
  gem 'activerecord', rails_version, :require => 'active_record'
  gem 'sqlite3', sqlite3_version
  gem 'sinatra', '>= 1.2.0'
  gem 'hashie'
end

group :development, :test do
  gem 'bson'
  # gem 'debugger'
  gem 'msgpack'
  gem 'oj'
  gem 'plist'
  gem 'rake'
  gem 'riot'
  gem 'rr'
  gem 'tilt'
end
