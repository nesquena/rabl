require 'tmpdir'
require 'pathname'
require File.expand_path('../../lib/rabl', __FILE__)

class TestHelperMethods
  include Rabl::Helpers
end

context "Rabl::Helpers" do
  setup do
    @helper_class = TestHelperMethods.new
    @user = User.new
  end

  context "for data_name method" do
    asserts "returns nil if no data" do
      @helper_class.data_name(nil)
    end.equals(nil)

    asserts "returns alias if hash with symbol is passed" do
      @helper_class.data_name(@user => :user)
    end.equals(:user)

    asserts "returns name of first object of a collection" do
      @helper_class.data_name([@user, @user])
    end.equals('users')

    asserts "returns name of an object" do
      @helper_class.data_name(@user)
    end.equals('user')
  end
end
