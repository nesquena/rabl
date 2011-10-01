require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')

context "UsersController" do
  helper(:pn!) { |ops|
    PhoneNumber.create!(ops.merge()) }
  helper(:json_output) { JSON.parse(last_response.body) }
  user1 = User.create!(:username => "billybob", :email => "billy@bob.com", :location => "SF", :is_admin => false)
  user2 = User.create!(:username => "joefrank", :email => "joe@frank.com", :location => "LA", :is_admin => false)
  user3 = User.create!(:username => "suziesmith", :email => "suzie@smith.com", :location => "NYC", :is_admin => true)
  users = [user1, user2, user3]
  pn_ops = { :area_code => "#{rand(9).to_s*3}", :prefix => "#{rand(9).to_s*3}", :suffix => "#{rand(9).to_s*4}"}
  pn1   = PhoneNumber.create(pn_ops.merge(:is_primary => true, :name => "Home", :user_id => user1.id))
  pn2   = PhoneNumber.create(pn_ops.merge(:is_primary => false, :name => "Work", :user_id => user1.id))
  pn3   = PhoneNumber.create(pn_ops.merge(:is_primary => true, :name => "Home", :user_id => user2.id))
  pn4   = PhoneNumber.create(pn_ops.merge(:is_primary => true, :name => "Home", :user_id => user3.id))

  context "for index action" do
    setup do
      get "/users"
    end

    asserts("contains user usernames") do
      json_output.map { |u| u["user"]["username"] }
    end.equals users.map(&:username)

    asserts("contains email") do
      json_output.map { |u| u["user"]["email"] }
    end.equals users.map(&:email)

    asserts("contains location") do
      json_output.map { |u| u["user"]["location"] }
    end.equals users.map(&:location)

    asserts("contains registered_at") do
      json_output.map { |u| u["user"]["registered_at"] }
    end.equals users.map(&:created_at).map(&:iso8601)

    asserts("contains role") do
      json_output.map { |u| u["user"]["role"] }
    end.equals ['normal', 'normal', 'admin']

    asserts("contains formatted phone numbers") do
      json_output.map { |u| u["user"]["pnumbers"].map { |n| n["formatted"] } }
    end.equals users.map { |u| u.phone_numbers.map(&:formatted) }
  end # index

  context "for show action" do
    setup do
      get "/users/#{user1.id}"
      # puts "J: " + json_output.inspect
    end

    asserts("contains username") { json_output["user"]["username"] }.equals user1.username
    asserts("contains email") { json_output["user"]["email"] }.equals user1.email
    asserts("contains location") { json_output["user"]["location"] }.equals user1.location
    asserts("contains registered_at") { json_output["user"]["registered_at"] }.equals user1.created_at.iso8601
    asserts("contains role node") { json_output["user"]["role"] }.equals "normal"
    asserts("contains first phone number") {
      json_output["user"]["pnumbers"][0]["pnumber"]["formatted"]
    }.equals user1.phone_numbers[0].formatted
    asserts("contains second phone number") {
      json_output["user"]["pnumbers"][1]["pnumber"]["formatted"]
    }.equals user1.phone_numbers[1].formatted
  end # show
end
