# Load Silence Functionality
require File.expand_path(File.dirname(__FILE__) + "/../../../test/silence.rb")

# Load Environment
silence_warnings do
  ENV["RAILS_ENV"] = "test"
  require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
  require 'test_help'
end

# Load Riot Test Environment
require File.expand_path(File.dirname(__FILE__) + "/../../../test/integration/test_init.rb")

# Run Migrations
silence_stream(STDOUT) do
  dbconf = YAML::load(File.open('config/database.yml'))[Rails.env]
  ActiveRecord::Base.establish_connection(dbconf)
  ActiveRecord::Base.logger = Logger.new(File.open('log/database.log', 'a'))
  silence_stream(STDOUT) { ActiveRecord::Migrator.up('db/migrate') }
end

class Riot::Situation
  def app
    ActionController::Dispatcher.new
  end
end

class ActiveSupport::TestCase
  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures  = false
end


