# frozen_string_literal: true

require File.expand_path('../teststrap', __FILE__)

# The gemspec lists files with git, so this only applies to a git checkout.
if File.exist?(File.expand_path('../../.git', __FILE__))
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

  context 'rabl.gemspec metadata' do
    setup do
      Dir.chdir(File.expand_path('../..', __FILE__)) do
        Gem::Specification.load('rabl.gemspec').metadata
      end
    end

    asserts('links the changelog, source and issue tracker on rubygems.org') do
      topic.values_at('changelog_uri', 'source_code_uri', 'bug_tracker_uri').map { |uri| uri.to_s[%r{\Ahttps://github\.com/nesquena/rabl\b}] }
    end.equals ['https://github.com/nesquena/rabl'] * 3
    asserts('requires MFA to push the gem') { topic['rubygems_mfa_required'] }.equals 'true'
  end
end
