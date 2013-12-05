require 'tmpdir'
require 'pathname'
require File.expand_path('../teststrap', __FILE__)

class TestHelperMethods
  include Rabl::Helpers
end

context "Rabl::Helpers" do
  setup do
    @helper_class = TestHelperMethods.new
    @user = User.new
  end

  # determine_object_root(@user, :user, true) => "user"
  # determine_object_root(@user, :person) => "person"
  # determine_object_root([@user, @user]) => "user"
  # def determine_object_root(data_token, data_name=nil, include_root=true)
  context "for determine_object_root method" do
    asserts "returns nil if include_root is false" do
      @helper_class.determine_object_root(@user, :user, false)
    end.equals(nil)

    asserts "returns user root name if include_root is true" do
      @helper_class.determine_object_root(@user, :user, true)
    end.equals("user")

    asserts "returns explicit alias if specified" do
      @helper_class.determine_object_root(@user, :person)
    end.equals("person")

    asserts "returns explicit alias if object is nil" do
      @helper_class.determine_object_root(nil, :person)
    end.equals("person")
  end

  context "for data_name method" do
    asserts "returns nil if no data" do
      @helper_class.data_name(nil)
    end.equals(nil)

    asserts "returns symbol if symbol with empty children" do
      @helper_class.data_name(:user)
    end.equals(:user)

    asserts "returns alias if hash with symbol is passed" do
      @helper_class.data_name(@user => :user)
    end.equals(:user)

    asserts "returns name of first object of a collection" do
      @helper_class.data_name([@user, @user])
    end.equals('users')

    asserts "returns name of an object" do
      @helper_class.data_name(@user)
    end.equals('user')

    asserts "returns table_name of collection if responds" do
      @coll = [@user, @user]
      mock(@coll).table_name { "people" }
      @helper_class.data_name(@coll)
    end.equals('people')
  end # data_name method

  context "for is_object method" do
    asserts "returns nil if no data" do
      @helper_class.is_object?(nil)
    end.equals(nil)

    asserts "returns true for an object" do
      @helper_class.is_object?(@user)
    end.equals(true)

    asserts "returns true for an object with each" do
      obj = Class.new { def each; end }
      @helper_class.is_object?(obj.new)
    end.equals(true)

    asserts "returns true for a hash alias" do
      @helper_class.is_object?(@user => :user)
    end.equals(true)

    asserts "returns true for a struct" do
      obj = Struct.new(:name)
      @helper_class.is_object?(obj.new('foo'))
    end.equals(true)

    asserts "returns false for an array" do
      @helper_class.is_object?([@user])
    end.equals(false)
  end # is_object method

  context "for is_collection method" do
    asserts "returns nil if no data" do
      @helper_class.is_collection?(nil)
    end.equals(nil)

    asserts "returns false for a struct" do
      obj = Struct.new(:name)
      @helper_class.is_collection?(obj.new('foo'))
    end.equals(false)

    asserts "returns false for an object" do
      @helper_class.is_collection?(@user)
    end.equals(false)

    asserts "returns false for an object with each" do
      obj = Class.new { def each; end }
      @helper_class.is_collection?(obj.new)
    end.equals(false)

    asserts "returns false for a hash alias" do
      @helper_class.is_collection?(@user => :user)
    end.equals(false)

    asserts "returns true for an array" do
      @helper_class.is_collection?([@user])
    end.equals(true)
  end # is_collection method
end
