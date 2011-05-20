class Phone < ActiveRecord::Base
  belongs_to :user
  def common_name; self.class.common_name; end

  validates_uniqueness_of :friendly, :scope => :user_id
  validates_length_of :friendly, :minimum => 3

  def username
    "#{user.login}#{id}"
  end

end

class SIPPhone < Phone
end

class CustSIPPhone < SIPPhone
  def self.common_name; 'Custom'; end

  before_create :set_password
  def set_password
    self.password = SecureRandom.base64(6)
  end
end

class ProvSIPPhone < SIPPhone
  def self.common_name; 'Business'; end
  validates_each :identifier do |record, attr, value|
    unless /^[0-9A-F]{12}$/i === value
      record.errors.add attr, 'not 12 digit HEX'
    end
  end

  validates_uniqueness_of :identifier

  before_create :set_password
  def set_password
    self.password = SecureRandom.base64(12)
  end

  before_save :normalize_mac
  def normalize_mac
    self.identifier.downcase!
  end
end

class ExternalPhone < Phone
  def self.common_name; 'External'; end
  validates_each :identifier do |record, attr, value|
    unless /^1?[-\. ]?\d{3}[-\. ]?\d{3}[-\. ]?\d{4}$/i === value
      record.errors.add attr, 'not 9 digit phone number'
    end
  end

  before_save :normalize_phone
  def normalize_phone
    /^1?[-\. ]?(\d{3})[-\. ]?(\d{3})[-\. ]?(\d{4})$/ === attributes['identifier']
    attributes['identifier'] = $1+$2+$3
  end
end
