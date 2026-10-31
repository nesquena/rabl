# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'rbconfig'
require 'stringio'
require File.expand_path('../teststrap', __FILE__)
require 'rabl/template'

# Errors raised by a template point at the template's file and line (#423)
context "Template errors" do
  helper(:view_path) { @view_path ||= Dir.mktmpdir }
  helper(:template_path) { |name| File.join(view_path, "#{name}.rabl") }
  helper(:write_template) { |name, source| File.write(template_path(name), source) }

  # Returns the "file:line" of the first backtrace frame of the error the block raises
  helper(:error_site) do |&block|
    begin
      block.call
      nil
    rescue StandardError => e
      e.backtrace.first[/\A.+?:\d+(?=:in )/]
    end
  end

  helper(:render_template) { |name| Rabl::Renderer.new(name, User.new, :view_path => view_path).render }

  teardown { FileUtils.remove_entry(view_path) }

  asserts "an error at the top level of the template" do
    write_template("top", "object @user\nattributes :name\nnil.no_such_method\n")
    error_site { render_template("top") }
  end.equals { "#{template_path('top')}:3" }

  asserts "an error in a node block" do
    write_template("in_node", "object @user\nnode(:boom) do |u|\n  u.no_such_method\nend\n")
    error_site { render_template("in_node") }
  end.equals { "#{template_path('in_node')}:3" }

  asserts "an error in a child block" do
    write_template("in_child", "object @user\nchild :hobbies do\n  attributes :name\n  node(:x) { |h| h.no_such_method }\nend\n")
    error_site { render_template("in_child") }
  end.equals { "#{template_path('in_child')}:4" }

  asserts "an error in a glue block" do
    write_template("in_glue", "object @user\n\nglue(@user) do\n  node(:x) { |u| u.no_such_method }\nend\n")
    error_site { render_template("in_glue") }
  end.equals { "#{template_path('in_glue')}:4" }

  asserts "an error in an extended template" do
    write_template("broken", "attributes :name\n\nnode(:x) { |u| u.no_such_method }\n")
    write_template("extending", "object @user\nextends 'broken'\n")
    error_site { render_template("extending") }
  end.equals { "#{template_path('broken')}:3" }

  asserts "an error in a partial" do
    write_template("broken_partial", "attributes :name\nnil.no_such_method\n")
    write_template("with_partial", "object @user\nnode(:p) { |u| partial('broken_partial', :object => u) }\n")
    error_site { render_template("with_partial") }
  end.equals { "#{template_path('broken_partial')}:2" }

  asserts "a syntax error names the template file and line" do
    write_template("syntax", "object @user\nattributes :name\nnode(:x) { |u| u.name ) }\n")
    begin
      render_template("syntax")
      nil
    rescue SyntaxError => e
      e.message.include?("#{template_path('syntax')}:3:")
    end
  end

  asserts "an error in a Tilt template" do
    write_template("tilt", "object @user\n\nnode(:x) { |u| u.no_such_method }\n")
    scope = Object.new
    scope.instance_variable_set(:@user, User.new)
    error_site { RablTemplate.new(template_path("tilt")).render(scope) }
  end.equals { "#{template_path('tilt')}:3" }

  asserts "an error in an inline Tilt template, such as a Sinatra __END__ template" do
    scope = Object.new
    scope.instance_variable_set(:@user, User.new)
    # the template's source starts at line 10 of the app's file
    template = RablTemplate.new(template_path("app"), 10) { "object @user\n\nnode(:x) { |u| u.no_such_method }\n" }
    [error_site { template.render(scope) }, error_site { RablTemplate.new(template_path("app"), 20) { template.data }.render(scope) }]
  end.equals { ["#{template_path('app')}:12", "#{template_path('app')}:22"] }

  asserts "the warning for extends inside a node names the template line" do
    write_template("warns", "object @user\nattributes :name\nnode(:x) do |u|\n  extends 'broken'\nend\n")
    stderr = $stderr
    $stderr = StringIO.new
    begin
      render_template("warns")
      $stderr.string[/^rabl: extends called while the template renders .* at (\S+) /, 1]
    ensure
      $stderr = stderr
    end
  end.equals { "#{template_path('warns')}:4" }

  asserts "an error in a template given as a string reports its line" do
    site = error_site { Rabl::Renderer.new("object @user\nattributes :name\nnil.no_such_method\n", User.new).render }
    site[/\d+\z/]
  end.equals "3"

  # The ActionView handler's code, compiled into a view method as ActionView does, raises
  # errors that point at the template file and line, which Rails shows on its error page.
  # It runs in its own process, as the handler is defined only when Rails is loaded.
  ["5.2.0", "8.1.0"].each do |rails_version|
    asserts "an error in a template rendered by the Rails #{rails_version[0]} handler" do
      write_template("rails", "object @user\nattributes :name\n\nnil.no_such_method\n")
      script = <<-'RUBY'
        require 'rabl'
        require 'active_support/core_ext/class/attribute'
        rails_version, path = ARGV
        Rails = Module.new
        Rails.define_singleton_method(:version) { rails_version }
        Mime = { :json => "application/json" }
        module ActionView
          class Template
            module Handlers; end
            def self.register_template_handler(*); end
          end
        end
        Rabl.register!

        handler = ActionView::Template::Handlers::Rabl
        template = Struct.new(:identifier, :source).new(path, File.read(path))
        code = handler.method(:call).arity == 1 ? handler.call(template) : handler.call(template, template.source)

        view = Object.new
        view.instance_variable_set(:@user, Object.new)
        def view.assigns; {}; end
        def view.local_assigns; {}; end
        view.singleton_class.class_eval("def compiled_template\n#{code}\nend", path, 0)

        begin
          view.compiled_template
        rescue StandardError => e
          puts e.backtrace.first[/\A.+?:\d+(?=:in )/]
        end
      RUBY
      lib = File.expand_path('../../lib', __FILE__)
      IO.popen([RbConfig.ruby, "-I", lib, "-e", script, rails_version, template_path("rails")], :err => [:child, :out], &:read).strip
    end.equals { "#{template_path('rails')}:4" }
  end
end
