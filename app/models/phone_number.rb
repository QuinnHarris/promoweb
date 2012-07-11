class PhoneNumber < ActiveRecord::Base
  belongs_to :customer

  @@types = %w(Work Mobile Home Fax Company Other)
  cattr_reader :types

  #validates_format_of :number_string, :with => /^1?[- \.]?\d{3}[- \.]?\d{3}[- \.]\d{4}/

  def self.main_column; 'number_string'; end

  def dial_string
    /([0-9\-. ]+)/ === number_string
    $1 && $1.gsub(/[^0-9]+/,'')
  end

  before_save :set_number
  def set_number
    return unless number_string
    if /^011/ === number_string
      self.number = number_string.gsub(/[^0-9]+/,'')
    else
      self.number = number_string.gsub(/^1/,'').gsub(/[^0-9]+/,'')[0..9]
    end
  end
end
