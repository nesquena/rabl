# Lives in <rabl>/test/integration/users_controller_test.rb
# Symlinked to fixture applications

begin # Sinatra
  require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')
rescue LoadError # Rails
  require File.expand_path(File.dirname(__FILE__) + '/../test_helper.rb')
end

context "UsersController" do
  helper(:json_output) { JSON.parse(last_response.body) }

  setup do
    create_users!
  end

  context "for index action" do
    # Tests `collection @users` extending from 'show' template

    setup do
      get "/users"
    end

    # Attributes (regular)
    asserts("contains user usernames") do
      json_output.map { |u| u["user"]["username"] }
    end.equals { @users.map(&:username) }
    asserts("contains email") do
      json_output.map { |u| u["user"]["email"] }
    end.equals { @users.map(&:email) }
    asserts("contains location") do
      json_output.map { |u| u["user"]["location"] }
    end.equals { @users.map(&:location) }

    # Attributes (custom name)
    asserts("contains registered_at") do
      json_output.map { |u| u["user"]["registered_at"] }
    end.equals { @users.map(&:created_at).map(&:utc).map(&:to_s) }

    # Node (renders based on attribute)
    asserts("contains role") do
      json_output.map { |u| u["user"]["role"] }
    end.equals ['normal', 'normal', 'admin']

    # Child (custom collection name)
    asserts("contains formatted phone numbers") do
      json_output.map { |u| u["user"]["pnumbers"].map { |n| n["pnumber"]["formatted"] } }
    end.equals { @users.map { |u| u.phone_numbers.map(&:formatted) } }

    # Node (renders collection partial)
    asserts("contains reversed node numbers") do
      json_output.map { |u| u["user"]["node_numbers"].map { |n| n["reversed"] } }
    end.equals { @users.map { |u| u.phone_numbers.map(&:formatted).map(&:reverse) } }
  end # index

  context "for show action" do
    # Tests `object :user => :person` custom parent node name
    setup do
      get "/users/#{@user1.id}"
    end

    # Attributes (regular)
    asserts("contains username") { json_output["person"]["username"] }.equals { @user1.username }
    asserts("contains email") { json_output["person"]["email"] }.equals { @user1.email }
    asserts("contains location") { json_output["person"]["location"] }.equals { @user1.location }
    # Attributes (custom name)
    asserts("contains registered_at") { json_output["person"]["registered_at"] }.equals { @user1.created_at.utc.to_s }
    # Node (renders based on attribute)
    asserts("contains role node") { json_output["person"]["role"] }.equals "normal"

    # Child (custom collection name)
    asserts("contains first phone number") {
      json_output["person"]["pnumbers"][0]["pnumber"]["formatted"]
    }.equals { @user1.phone_numbers[0].formatted }
    asserts("contains second phone number") {
      json_output["person"]["pnumbers"][1]["pnumber"]["formatted"]
    }.equals { @user1.phone_numbers[1].formatted }

    # Node (renders collection partial)
    asserts("contains first node number") {
      json_output["person"]["node_numbers"][0]["formatted"]
    }.equals { @user1.phone_numbers[0].formatted }
    asserts("contains second node number") {
      json_output["person"]["node_numbers"][1]["formatted"]
    }.equals { @user1.phone_numbers[1].formatted }
  end # show
end