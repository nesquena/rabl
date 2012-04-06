require File.expand_path('../teststrap', __FILE__)
require File.expand_path('../../lib/rabl', __FILE__)
require File.expand_path('../../lib/rabl/template', __FILE__)
require File.expand_path('../models/user', __FILE__)
require File.expand_path('../models/ormless', __FILE__)

context "Rabl::ObjectNode" do

  setup do
    @users = [User.new, User.new]
    @user = User.new
  end

  context "#to_hash" do
    context "when given an object" do
      setup do
        Rabl::ObjectNode.new(@user, :root_name => "person") { attributes :name => :name }
      end

      asserts "that the object is set properly" do
        topic.to_hash
      end.equivalent_to({ "person" => { :name => "rabl" } })
    end

  end
end