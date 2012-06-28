source :rubygems

# Specify your gem's dependencies in rabl.gemspec
gemspec

gem "rake"
gem "i18n", '~> 0.6'

platforms :mri_18 do
  gem 'SystemTimer'
end

# FIXTURES
group :test do
  gem 'rack-test', :require => "rack/test"
  gem 'activerecord', :require => "active_record"
  gem 'sqlite3'
  gem 'sinatra', '>= 1.2.0'
end

group :development, :test do
  gem 'debugger'
end
