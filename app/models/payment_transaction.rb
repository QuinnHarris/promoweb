class PaymentTransaction < ActiveRecord::Base
  belongs_to :method, :class_name => 'PaymentMethod', :foreign_key => 'method_id'
  belongs_to :order
  
  composed_of :amount, :class_name => 'Money', :mapping => %w(amount units)
  serialize :data
end

class PaymentError < PaymentTransaction
  def message
    data.collect { |k, v| "#{k}: #{v}" }.join(', ')
  end
end

class PaymentAuthorize < PaymentTransaction
  validates_numericality_of :amount, :greater_than => 0
end

class PaymentCharge < PaymentTransaction
  validates_numericality_of :amount, :greater_than => 0
  def refunded; data[:refunded]; end
  def refunded!
    write_attribute(:data, (read_attribute(:data) || {}).merge(:refunded => true))
  end
end

class PaymentCredit < PaymentTransaction
  validates_numericality_of :amount, :less_than => 0
end
