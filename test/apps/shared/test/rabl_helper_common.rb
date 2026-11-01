require 'json'
require 'time'
require 'rack/test'

# Shared by the generated apps' test/rabl_helper.rb, which defines `app` and `with_caching`
module RablAppTestHelpers
  include Rack::Test::Methods

  def json_output
    JSON.parse(last_response.body)
  end

  def create_users!
    User.delete_all
    PhoneNumber.delete_all
    @user1 = User.create!(:username => "billybob", :email => "billy@bob.com", :location => "SF", :is_admin => false)
    @user2 = User.create!(:username => "joefrank", :email => "joe@frank.com", :location => "LA", :is_admin => false)
    @user3 = User.create!(:username => "suziesmith", :email => "suzie@smith.com", :location => "NYC", :is_admin => true)
    @users = [@user1, @user2, @user3]
    numbers = { :area_code => "415", :prefix => "555", :suffix => "0100" }
    PhoneNumber.create!(numbers.merge(:is_primary => true, :name => "Home", :user_id => @user1.id))
    PhoneNumber.create!(numbers.merge(:is_primary => false, :name => "Work", :user_id => @user1.id, :suffix => "0199"))
    PhoneNumber.create!(numbers.merge(:is_primary => true, :name => "Home", :user_id => @user2.id))
    PhoneNumber.create!(numbers.merge(:is_primary => true, :name => "Home", :user_id => @user3.id))
  end

  def create_posts!
    create_users!
    Post.delete_all
    @post1 = Post.create!(:title => "Foo", :body => "Bar", :user_id => @user1.id)
    @post2 = Post.create!(:title => "Baz", :body => "Bah", :user_id => @user2.id)
    @post3 = Post.create!(:title => "Kaz", :body => "<script>alert('xss & test');</script>", :user_id => @user3.id)
    @posts = [@post1, @post2, @post3]
  end
end
