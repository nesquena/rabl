require File.expand_path('../teststrap',__FILE__)
require 'rabl/template'

class Scope
end

context "RablTemplate" do
  asserts "that it registers for .rabl files" do
    Tilt['test.rabl']
  end.equals RablTemplate

  context "#render" do
    setup do
      RablTemplate.new { |t| "code(:lol) { 'wut' }" }
    end

    asserts "preparing and evaluating templates on #render" do
      topic.render
    end.matches %r{"lol":"wut"}

    3.times do |n|
      asserts "can be rendered #{n} time(s)" do
        topic.render
      end.matches %r{"lol":"wut"}
    end

    # asserts "that it can be passed locals" do
    #   template = RablTemplate.new { "code(:name) { @name }" }
    #   template.render(Object.new, :object => 'Bob')
    # end.matches %r{"name":"Bob"}

    asserts "that it evaluates in object scope" do
      template = RablTemplate.new { "code(:lol) { @name }" }
      scope = Object.new
      scope.instance_variable_set :@name, 'Joe'
      template.render(scope)
    end.matches %r{"lol":"Joe"}

    asserts "that it can pass a block for yield" do
      template = RablTemplate.new { "code(:lol) { 'Hey ' + yield + '!' }" }
      template.render { 'Joe' }
    end.matches %r{"lol":"Hey Joe!"}
  end

  context "#render compiled" do
    # asserts "that it can be passed locals" do
    #   template = RablTemplate.new { "code(:name) { @name }" }
    #   template.render(Scope.new, :object => 'Bob')
    # end.matches %r{"name":"Bob"}

    asserts "that it evaluates in an object scope" do
      template = RablTemplate.new { "code(:lol) { @name }" }
      scope = Scope.new
      scope.instance_variable_set :@name, 'Joe'
      template.render(scope)
    end.matches %r{"lol":"Joe"}

    asserts "that it can pass a block for yield" do
      template = RablTemplate.new { "code(:lol) { 'Hey ' + yield + '!' }" }
      template.render(Scope.new) { 'Joe' }
    end.matches %r{"lol":"Hey Joe!"}
  end
end
