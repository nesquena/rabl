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

  gem 'activerecord', '>= 6.1', :require => 'active_record'
  gem 'sqlite3', '>= 1.5'
  gem 'sinatra', '>= 1.2.0'
  gem 'hashie'
end

group :development, :test do
  gem 'bson'
  # gem 'debugger'
  gem 'msgpack'
  gem 'oj', '>= 3.17.7' # the tests of rabl's per-call Oj options (#744) need 3.17.7+
  gem 'plist'
  gem 'rake'
  gem 'riot'
  gem 'rr'
  gem 'tilt'
end
