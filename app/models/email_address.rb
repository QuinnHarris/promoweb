class EmailAddress < ActiveRecord::Base
  belongs_to :customer

  def self.main_column; 'address'; end

  validates :address, :presence => true, :email => true
end
