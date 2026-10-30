# frozen_string_literal: true

require File.expand_path('../teststrap', __FILE__)

context 'rabl.gemspec' do
  setup do
    Dir.chdir(File.expand_path('../..', __FILE__)) do
      Gem::Specification.load('rabl.gemspec').files
    end
  end

  asserts('packages the library') { topic.include?('lib/rabl.rb') && topic.include?('lib/rabl/engine.rb') }
  asserts('packages the license and readme') { topic.include?('MIT-LICENSE') && topic.include?('README.md') }
  denies('packages tests or fixtures') { topic.any? { |f| f.start_with?('test/', 'fixtures/') } }
end
