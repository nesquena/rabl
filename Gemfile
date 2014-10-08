source 'https://rubygems.org'

# Specify your gem's dependencies in rabl.gemspec
gemspec

gem 'rake', :require => false
gem 'i18n', '~> 0.6'

platforms :mri_18 do
  gem 'SystemTimer'
  gem 'json'
end

group :test do
  # RABL TEST
  if RUBY_VERSION < "1.9"
    spec.add_dependency "activesupport", "~> 3"
  else
    spec.add_dependency "activesupport", "~> 4"
  end
  
  gem 'builder'

  # FIXTURES
  gem 'rack-test', :require => 'rack/test'
  gem 'activerecord', :require => 'active_record'
  gem 'sqlite3'
  gem 'sinatra', '>= 1.2.0'
end

group :development, :test do
  # gem 'debugger'
end
