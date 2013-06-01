class PaymentTransaction < ActiveRecord::Base
  belongs_to :method, :class_name => 'PaymentMethod', :foreign_key => 'method_id'
  belongs_to :order
  belongs_to :invoice
  
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

class PaymentRequest < PaymentTransaction
  validates_numericality_of :amount, :greater_than => 0
end

class BitCoinTransaction < PaymentTransaction
  validates_numericality_of :amount, :greater_than => 0

  def rate; data[:rate]; end
  def rate=(val)
    write_attribute(:data, (read_attribute(:data) || {}).merge(:rate => val) )
  end

  def discount; data[:discount] || 0.0; end
  def discount=(val)
    write_attribute(:data, (read_attribute(:data) || {}).merge(:discount => val) )
  end

  def pay_address
    method.display_number
  end
end

class PaymentBitCoinAccept < BitCoinTransaction
  # order.rb:payment_charges is hardcoded to accept confirmation when there is an auth_code

  CONFIRM = 4

  def confirmations; data[:confirmations] || 0.0; end
  def confirmations=(val)
    write_attribute(:data, (read_attribute(:data) || {}).merge(:confirmations => val) )
    if val >= CONFIRM and auth_code != 'CONFIRMED'
      write_attribute(:auth_code, 'CONFIRMED')
    end
  end
  def confirmed?
    confirmations >= CONFIRM
  end

  def coins; data[:coins]; end
  def coins=(val)
    write_attribute(:data, (read_attribute(:data) || {}).merge(:coins => val) )
  end 

  def fudge; data[:fudge]; end
  def fudge=(val)
    write_attribute(:data, (read_attribute(:data) || {}).merge(:fudge => val) )
  end  

  def comment
    str = "#{coins} BTC @ #{rate}/BTC + #{discount}%"
    str += " [#{fudge.to_perty}]" if fudge
    if confirmations < 12
      str += " (#{confirmations} conf)"
    else
      str += " Confirmed"
    end
    str
  end
end

class PaymentBitCoinRequest < BitCoinTransaction
  EXPIRES = 1.hour

  def expires
    EXPIRES - (Time.now - created_at)
  end
  def active?
    (Time.now - created_at) < EXPIRES
  end

  def coins
    BitCoinRate.bc_USD(rate, amount * (1.0 - discount/100.0))
  end

  def chargeable
    BitCoinRate.bc_USD(rate, order.total_chargeable * (1.0 - discount/100.0))
  end

  def url
    "bitcoin:#{pay_address}?amount=#{chargeable}&label=Mountain%20Xpress%20Promotions"
  end

  def comment
    if active?
      "-#{discount}% @ #{rate.to_perty}/BTC = #{coins} BTC"
    else
      "#{rate.to_perty}/BTC EXPIRED"
    end
  end
end
