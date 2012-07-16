require 'active_support/inflector' # for the sake of pluralizing

module Rabl
  module Helpers

    # data_object(data) => <AR Object>
    # data_object(@user => :person) => @user
    # data_object(:user => :person) => @_object.send(:user)
    def data_object(data)
      data = (data.is_a?(Hash) && data.keys.size == 1) ? data.keys.first : data
      data.is_a?(Symbol) && @_object ? @_object.__send__(data) : data
    end

    # data_object_attribute(data) => @_object.send(data)
    def data_object_attribute(data)
      escape_output @_object.__send__(data)
    end

    # data_name(data) => "user"
    # data_name(@user => :person) => :person
    # data_name(@users) => :user
    # data_name([@user]) => "users"
    # data_name([]) => "array"
    def data_name(data)
      return nil unless data # nil or false
      return data.values.first if data.is_a?(Hash) # @user => :user
      data = @_object.__send__(data) if data.is_a?(Symbol) && @_object # :address
      if is_collection?(data) && data.respond_to?(:first) # data collection
        data_name(data.first).to_s.pluralize if data.first.present?
      elsif is_object?(data) # actual data object
        object_name = object_root_name if object_root_name
        object_name ||= collection_root_name.to_s.singularize if collection_root_name
        object_name ||= data.class.respond_to?(:model_name) ? data.class.model_name.element : data.class.to_s.downcase
        object_name
      end
    end

    # Returns the object rootname based on if the root should be included
    # Can be called with data as a collection or object
    # determine_object_root(@user, true) => "user"
    # determine_object_root(@user => :person) => "person"
    # determine_object_root([@user, @user]) => "user"
    def determine_object_root(data, include_root=true)
      return if object_root_name == false
      root_name = data_name(data).to_s if include_root
      if is_object?(data)
        root_name
      elsif is_collection?(data)
        object_root_name || (root_name.singularize if root_name)
      end
    end

    # Returns true if obj is not a collection
    # is_object?(@user) => true
    # is_object?([]) => false
    # is_object?({}) => false
    def is_object?(obj)
      obj && (!data_object(obj).respond_to?(:map) || !data_object(obj).respond_to?(:each))
    end

    # Returns true if the obj is a collection of items
    def is_collection?(obj)
      obj && data_object(obj).respond_to?(:map) && data_object(obj).respond_to?(:each)
    end

    # Returns the scope wrapping this engine, used for retrieving data, invoking methods, etc
    # In Rails, this is the controller and in Padrino this is the request context
    def context_scope
      defined?(@_scope) ? @_scope : nil
    end

    # Returns the root (if any) name for an object within a collection
    # Sets the name of the object i.e "person"
    # => { "users" : [{ "person" : {} }] }
    def object_root_name
      defined?(@_object_root_name) ? @_object_root_name : nil
    end

    # Returns the root for the collection
    # Sets the name of the collection i.e "people"
    #  => { "people" : [] }
    def collection_root_name
      defined?(@_collection_name) ? @_collection_name : nil
    end

    # Fetches a key from the cache and stores rabl template result otherwise
    # fetch_from_cache('some_key') { ...rabl template result... }
    def fetch_result_from_cache(cache_key, cache_options=nil, &block)
      expanded_cache_key = ActiveSupport::Cache.expand_cache_key(cache_key, :rabl)
      Rabl.configuration.cache_engine.fetch(expanded_cache_key, cache_options, &block)
    end

    # Returns true if the cache has been enabled for the application
    def template_cache_configured?
      defined?(Rails) && defined?(ActionController::Base) && ActionController::Base.perform_caching
    end

    # Escape output if configured and supported
    def escape_output(data)
      (data && defined?(ERB::Util.h) && Rabl.configuration.escape_all_output) ? ERB::Util.h(data) : data
    end

  end
end
