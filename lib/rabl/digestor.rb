module Rabl
  class Digestor < ActionView::Digestor
    # Override the original digest function to ignore partial which
    # rabl doesn't use the Rails conventional _ symbol.
    if Gem::Version.new(Rails.version) >= Gem::Version.new('5.0.0.beta1')
      require 'rabl/digestor/rails5'
    elsif Gem::Version.new(Rails.version) >= Gem::Version.new('4.1')
      require 'rabl/digestor/rails41'
    else
      require 'rabl/digestor/rails3'
    end

    private
      def dependency_digest
        template_digests = (dependencies - [template.virtual_path]).collect do |template_name|
          if Gem::Version.new(Rails.version) >= Gem::Version.new('4.1')
            Digestor.digest(:name => template_name, :finder => finder)
          else
            Digestor.digest(template_name, format, finder)
          end
        end

        (template_digests + injected_dependencies).join("-")
      end
  end
end
