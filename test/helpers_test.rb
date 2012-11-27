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

    context 'when is_object?' do
      setup do
        stub(@helper_class).is_object? { true }
        mock(@helper_class).name_for_data_object(@user) { 'blankenfresh' }
      end

      asserts "calls #name_for_data_object" do
        @helper_class.data_name(@user)
      end.equals('blankenfresh')
    end
  end # data_name method

  context 'for name_for_data_object method' do
    context 'when object_root_name not nil' do
      setup do
        stub(@helper_class).object_root_name { 'a_name' }
      end

      asserts 'returns object_root_name' do
        @helper_class.name_for_data_object(@user)
      end.equals('a_name')
    end

    context 'when object_root_name is nil' do
      setup do
        stub(@helper_class).object_root_name { nil }
      end

      context 'when has a collection_root_name' do
        setup do
          stub(@helper_class).collection_root_name { 'peoples' }
        end

        asserts 'returns the singularized collection name' do
          @helper_class.name_for_data_object(@user)
        end.equals('people')
      end

      context 'when does not have collection_root_name' do
        setup do
          stub(@helper_class).collection_root_name { nil }
        end

        context 'when calling element_name_for_data_object_class' do
          setup do
            stub(@helper_class).element_name_for_data_object_class(@user.class) {
              'element_name'
            }
          end
          asserts 'gets element_name_for_data_object_class' do
            @helper_class.name_for_data_object(@user)
          end.equals('element_name')
        end # when calling element_name_for_data_object_class
      end # when does not have collection_root_name
    end # when object_root_name is nil
  end #name_for_data_object method

  context 'for element_name_for_data_object_class method' do
    context 'when class responds_to :model_name' do
      setup do
        @model_class  = Object.new

        # rr can't stub respond_to?
        def @model_class.respond_to?(thing)
          if thing == :model_name
            true
          else
            super
          end
        end

        stub(@helper_class).element_name_for_model_class(@model_class) {
          'name_from #element_name_for_model_class'
        }
      end

      asserts 'uses result from #element_name_for_model_class' do
        @helper_class.element_name_for_data_object_class(@model_class)
      end.equals('name_from #element_name_for_model_class')

    end # when class responds_to :model_name

    context 'when class does not responds_to :model_name' do
      setup do
        @model_class  = Object.new

        # rr can't stub respond_to?
        def @model_class.respond_to?(thing)
          if thing == :model_name
            false
          else
            super
          end
        end

        stub(@model_class).to_s { 'Dilworth' }
      end #setup

      asserts 'it uses calls chain to_s.downcase on class' do
        @helper_class.element_name_for_data_object_class(@model_class)
      end.equals('dilworth')
    end
  end #element_name_for_data_object_class

  context 'for element_name_for_model_class method' do
    context 'when respond_to :element' do
      setup do
        # using generic object
        # and descriptive string
        # here since
        # stubbing :respond_to? on a rr
        # mock always returns false
        @mock_class     = Object.new
        mock_model_name = 'ActiveModel::Naming instance'

        stub(mock_model_name).respond_to?(:element)     { true }
        stub(mock_model_name).element      { 'another_user' }
        stub(@mock_class).model_name  { mock_model_name }
      end

      asserts "reads element accessor" do
        @helper_class.element_name_for_model_class(@mock_class)
      end.equals('another_user')

    end # respond_to :element

    context 'when does not respond_to :element' do
      setup do
        @mock_class     = Object.new
        mock_model_name = 'ActiveSupport::ModelName rails 232 fix'

        stub(mock_model_name).respond_to?(:element)     { false }
        stub(@mock_class).model_name  { mock_model_name }
      end

      asserts "uses ActiveSupport::Inflector" do
        @helper_class.element_name_for_model_class(@mock_class)
      end.equals('model_name rails 232 fix')
    end
  end #element_name_for_model_class

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
