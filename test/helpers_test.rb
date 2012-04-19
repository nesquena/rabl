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
  end # data_name method

  context "for is_object method" do
    asserts "returns nil if no data" do
      @helper_class.is_object?(nil)
    end.equals(nil)

    asserts "returns true for an object" do
      @helper_class.is_object?(@user)
    end.equals(true)

    # asserts "returns true for an object with each" do
    #   obj = Class.new { def each; end }
    #   @helper_class.is_object?(obj.new)
    # end.equals(true)

    asserts "returns true for a hash alias" do
      @helper_class.is_object?(@user => :user)
    end.equals(true)

    asserts "returns false for an array" do
      @helper_class.is_object?([@user])
    end.equals(false)
  end # is_object method

  context "for is_collection method" do
    asserts "returns nil if no data" do
      @helper_class.is_collection?(nil)
    end.equals(nil)

    asserts "returns false for an object" do
      @helper_class.is_collection?(@user)
    end.equals(false)

    # asserts "returns false for an object with each" do
    #  obj = Class.new { def each; end }
    #  @helper_class.is_collection?(obj.new)
    # end.equals(false)

    asserts "returns false for a hash alias" do
      @helper_class.is_collection?(@user => :user)
    end.equals(false)

    asserts "returns true for an array" do
      @helper_class.is_collection?([@user])
    end.equals(true)
  end # is_collection method
end
