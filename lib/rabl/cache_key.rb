# frozen_string_literal: true

require 'digest/sha1'

module Rabl
  # Builds the parts of template cache keys. These are module functions rather than
  # Engine methods so that they never shadow helpers a template calls.
  module CacheKey
    module_function

    # Returns a digest of the given parts
    # CacheKey.digest(["app/views/show.rabl", "object @user"]) => "4a1b..."
    def digest(parts)
      digest = Digest::SHA1.new
      Array(parts).flatten.each { |part| digest << part.to_s << "\0" }
      digest.hexdigest
    end

    # Returns a path that stays the same when the application moves: relative to the
    # working directory when inside it, and nil for "(eval)" locations (the identity of
    # the parent template tells evaluated sources apart).
    # ceiling: paths outside the working directory stay absolute, so moving them changes
    # the keys; a configurable root would let those move too.
    def path(path)
      path = path.to_s.dup.force_encoding(Encoding::BINARY) # paths may differ in encoding
      return if path.empty? || path.start_with?("(eval")

      root = (File.join(Dir.pwd, "").force_encoding(Encoding::BINARY) rescue nil)
      root && path.start_with?(root) ? path.byteslice(root.bytesize..-1) : path
    end

    # Returns the options that change the shape of a nested (hash format) rendering;
    # with the default configuration a JSON rendering has none
    # CacheKey.shape(:format => "hash", :root => true) => ["root", "no_child_root"]
    def shape(options)
      return [] unless options[:format].to_s == "hash"

      shape = []
      shape << "root" if options[:root]
      shape << "no_child_root" unless options[:child_root]
      shape << "object_root=#{options[:object_root_name]}" if options[:object_root_name]
      shape << "except=#{Array(options[:except]).join(',')}" if options[:except]
      shape
    end
  end
end
