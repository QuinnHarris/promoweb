class PhoneNumber < ActiveRecord::Base
  belongs_to :customer

  @@types = %w(Work Mobile Home Fax Company Other)
  cattr_reader :types

  #validates_format_of :number_string, :with => /^1?[- \.]?\d{3}[- \.]?\d{3}[- \.]\d{4}/

  before_save :set_number
  def set_number
    self.number = number_string.gsub(/^1/,'').gsub(/[^0-9]+/,'')[0..9]
  end
end
