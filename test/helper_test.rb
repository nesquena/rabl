require File.expand_path('../teststrap',   __FILE__)
require File.expand_path('../../lib/rabl/helpers', __FILE__)
class Helpers; extend Rabl::Helpers; end

context "Rabl::Helpers" do
  context "#fetch_source" do
    asserts "that it strictly finds a single file" do
      Helpers.fetch_source('user',
        :view_path => File.expand_path('../views', __FILE__))
    end.matches "user.rabl"

    asserts "that it strictly finds an exact match" do
      Helpers.fetch_source('usr',
        :view_path => File.expand_path('../views', __FILE__))
    end.equals nil
  end
end
