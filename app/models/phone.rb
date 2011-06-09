class Phone < ActiveRecord::Base
  belongs_to :user

  validates_uniqueness_of :name, :scope => :user_id
  validates_length_of :name, :minimum => 3
  validates_format_of :identifier, :with => /^[0-9A-F]{12}$/i
  validates_uniqueness_of :identifier

  before_save :normalize_mac
  def normalize_mac
    self.identifier.downcase!
  end
end
