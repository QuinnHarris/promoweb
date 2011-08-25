class EmailAddress < ActiveRecord::Base
  belongs_to :customer

  def self.main_column; 'address'; end

  before_save :strip_address
  def strip_address
    self.address.strip!
  end

  validates :address, :presence => true, :email => true
end
