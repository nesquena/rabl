PADRINO_ENV = 'test' unless defined?(PADRINO_ENV)
require File.expand_path(File.dirname(__FILE__) + "/../config/boot")
ActiveRecord::Migrator.up('db/migrate') # Load up test migrations

# Specify your app using the #app helper inside a context.
# Takes either an app class or a block argument.
# app { Padrino.application }
# app { PadrinoTest.tap { |app| } }

class Riot::Situation
  include Rack::Test::Methods
  ##
  # You can handle all padrino applications using instead:
  #   Padrino.application
  # Or just the Application itself like:
  #   PadrinoTest.tap { |app|  }

  def app
    @app || Padrino.application
  end

  # Construct all the users needed for testing
  def create_users!
    User.delete_all; PhoneNumber.delete_all
    @user1 = User.create!(:username => "billybob", :email => "billy@bob.com", :location => "SF", :is_admin => false)
    @user2 = User.create!(:username => "joefrank", :email => "joe@frank.com", :location => "LA", :is_admin => false)
    @user3 = User.create!(:username => "suziesmith", :email => "suzie@smith.com", :location => "NYC", :is_admin => true)
    @users = [@user1, @user2, @user3]
    pn_ops = { :area_code => "#{rand(9).to_s*3}", :prefix => "#{rand(9).to_s*3}", :suffix => "#{rand(9).to_s*4}"}
    PhoneNumber.create(pn_ops.merge(:is_primary => true, :name => "Home", :user_id => @user1.id))
    PhoneNumber.create(pn_ops.merge(:is_primary => false, :name => "Work", :user_id => @user1.id))
    PhoneNumber.create(pn_ops.merge(:is_primary => true, :name => "Home", :user_id => @user2.id))
    PhoneNumber.create(pn_ops.merge(:is_primary => true, :name => "Home", :user_id => @user3.id))
  end
end

class Riot::Context
  # Set the Rack app which is to be tested.
  #
  #   context "MyApp" do
  #     app { [200, {}, "Hello!"] }
  #     setup { get '/' }
  #     asserts(:status).equals(200)
  #   end
  def app(app=nil, &block)
    setup { @app = (app || block.call) }
  end
end

