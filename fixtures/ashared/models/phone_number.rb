# frozen_string_literal: true

class PhoneNumber < ActiveRecord::Base
  belongs_to :user

  def formatted
    "(#{self.area_code}) #{self.prefix}-#{self.suffix}"
  end
end
