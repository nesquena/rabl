# Load Silence Functionality
require File.expand_path(File.dirname(__FILE__) + "/../../../test/silence.rb")

silence_warnings do
  PADRINO_ENV = 'test' unless defined?(PADRINO_ENV)
  require File.expand_path(File.dirname(__FILE__) + "/../config/boot")
  silence_stream(STDOUT) { ActiveRecord::Migrator.up('db/migrate') } # Load up test migrations
end

# Load Riot Test Environment
require File.expand_path(File.dirname(__FILE__) + "/../../../test/integration/test_init.rb")

class Riot::Situation
  def app
    @app || Padrino.application
  end
end

