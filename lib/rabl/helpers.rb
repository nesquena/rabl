require 'active_support/inflector' # for the sake of pluralizing

module Rabl
  module Helpers

    # data_object(data) => <AR Object>
    # data_object(@user => :person) => @user
    # data_object(:user => :person) => @_object.send(:user)
    def data_object(data)
      data = (data.is_a?(Hash) && data.keys.size == 1) ? data.keys.first : data
      data.is_a?(Symbol) && @_object ? @_object.send(data) : data
    end

    # data_name(data) => "user"
    # data_name(@user => :person) => :person
    # data_name(@users) => :user
    # data_name([@user]) => "user"
    # data_name([]) => "array"
    def data_name(data)
      return nil unless data # nil or false
      return data.values.first if data.is_a?(Hash) # @user => :user
      data = @_object.send(data) if data.is_a?(Symbol) && @_object # :address
      if data.respond_to?(:first)
        data_name(data.first).to_s.pluralize if data.first.present?
      else # actual data object
        object_name = @_collection_name.to_s.singularize if defined? @_collection_name
        object_name ||= data.class.respond_to?(:model_name) ? data.class.model_name.element : data.class.to_s.downcase
        object_name
      end
    end

    # Returns true if obj is not enumerable
    # is_object?(@user) => true
    # is_object?([]) => false
    # is_object?({}) => false
    def is_object?(obj)
      obj && !data_object(obj).respond_to?(:each)
    end

    # Returns true if the obj is a collection of items
    def is_collection?(obj)
      obj && data_object(obj).respond_to?(:each)
    end

  end
end
