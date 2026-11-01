# frozen_string_literal: true

require File.expand_path('../teststrap', __FILE__)

# The suite loads rabl with warnings silenced (with its test libraries), so loading it with
# warnings on runs in its own process
context 'Loading rabl with warnings on' do
  asserts("gives no warnings from rabl's files") do
    lib = File.expand_path('../../lib', __FILE__)
    script = "require 'oj'; require 'tilt'; require 'rabl'; Rabl.register!"
    output = IO.popen([RbConfig.ruby, '-w', '-I', lib, '-e', script, { :err => [:child, :out] }], &:read)
    output.lines.select { |line| line.start_with?("#{lib}/") }
  end.equals []
end
