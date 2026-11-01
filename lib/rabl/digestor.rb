# frozen_string_literal: true

require 'action_view'

module Rabl
  # Rails' digestor, under rabl's name: rabl.rb defines it only with the rest of the Rails integration, so
  # Engine#digestor_available? checks for it before adding a template digest to a cache key
  class Digestor < ActionView::Digestor
  end
end
