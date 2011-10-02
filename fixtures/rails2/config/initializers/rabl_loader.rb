# Run Migrations
require 'activerecord'
dbconf = YAML::load(File.open('config/database.yml'))[Rails.env]
ActiveRecord::Base.establish_connection(dbconf)
ActiveRecord::Base.logger = Logger.new(File.open('log/database.log', 'a'))
ActiveRecord::Migrator.up('db/migrate')