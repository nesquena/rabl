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
    # CacheKey.path("/app/views/show.rabl", "/app/") => "views/show.rabl"
    def path(path, root = self.root)
      path = path.to_s.dup.force_encoding(Encoding::BINARY) # paths may differ in encoding
      return if path.empty? || path.start_with?("(eval")

      root && path.start_with?(root) ? path.byteslice(root.bytesize..-1) : path
    end

    # Returns the column a block starts at, which tells apart blocks on one line, or nil when
    # the runtime doesn't expose it.
    # ceiling: without RubyVM::InstructionSequence (e.g. on JRuby), blocks that start on the
    # same line of a template share an identity; put them on separate lines, or give them
    # distinct cache keys.
    def column(block)
      return unless defined?(RubyVM::InstructionSequence)

      iseq = RubyVM::InstructionSequence.of(block)
      iseq && iseq.to_a[4][:code_location][1]
    rescue StandardError
      nil
    end

    # Returns the working directory with a trailing separator, as bytes, or nil if it is gone
    def root
      File.join(Dir.pwd, "").force_encoding(Encoding::BINARY)
    rescue SystemCallError
      nil
    end

    # Returns the options that change the shape of a rendering. A nested (hash format)
    # rendering gets its root options from its parent; for other formats only root
    # options given explicitly are added, so default keys have none.
    # CacheKey.shape(:format => "hash", :root => true) => ["root", "no_child_root"]
    # CacheKey.shape(:format => "json", :except => :b) => ["except=:b"]
    def shape(options)
      shape = []

      if options[:format].to_s == "hash"
        shape << "root" if options[:root]
        shape << "no_child_root" unless options[:child_root]
        shape << "object_root=#{options[:object_root_name].inspect}" if options[:object_root_name]
      else
        shape << "root=#{options[:root].inspect}" if options.key?(:root)
        shape << "child_root=#{options[:child_root].inspect}" if options.key?(:child_root)
      end

      shape << "except=#{Array(options[:except]).map { |name| name.inspect }.join(',')}" if options[:except]
      shape
    end
  end
end
