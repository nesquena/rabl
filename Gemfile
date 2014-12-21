source 'https://rubygems.org'

# Specify your gem's dependencies in rabl.gemspec
gemspec

gem 'i18n', '~> 0.6'

platforms :mri_18 do
  gem 'SystemTimer'
  gem 'json'
end

group :test do
  # RABL TEST
  gem 'builder'

  # FIXTURES
  gem 'rack-test', :require => 'rack/test'
  gem 'activerecord', :require => 'active_record'
  gem 'sqlite3'
  gem 'sinatra', '>= 1.2.0'
  gem 'hashie'
end

group :development, :test do
  # gem 'debugger'
end
