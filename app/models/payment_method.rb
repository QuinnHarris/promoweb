class PaymentMethod < ActiveRecord::Base
  belongs_to :customer
  belongs_to :address
  has_many :transactions, :class_name => 'PaymentTransaction', :foreign_key => 'method_id', :order => "id DESC"
  serialize :data
  
#  validates_uniqueness_of :display_number, :scope => :customer_id
  
  def creditable?; false; end
  def type_notes; nil; end
  
  PaymentTransaction
  def authorize(order, comment = nil)
    PaymentAuthorize.create({
      :method => self,
      :order => order,
      :amount => Money.new(0),
      :comment => comment
    })
  end
  
  def charge(order, amount, comment, data = nil)
    PaymentCharge.create({
      :method => self,
      :order => order,
      :amount => amount,
      :comment => comment,
      :data => data
    })
  end
  
  def credit(order, amount, comment, data = nil)
    PaymentCredit.create({
      :method => self,
      :order => order,
      :amount => -amount,
      :comment => comment,
      :data => data
    })   
  end

  def revoke!; end;
  def fee; 0.0; end
end

class OnlineMethod < PaymentMethod
  def self.gateway
    secrets = YAML.load_file("#{Rails.root}/config/secrets")
    ActiveMerchant::Billing::TrustCommerceGateway.new(secrets['trust_commerce'][RAILS_ENV].symbolize_keys)
  end
end

class PaymentCreditCard < OnlineMethod
  def type_name; "Credit Card"; end
  def has_name?; true; end
  def has_number?; true; end
  
  def self.store(order, creditcard, address)
    payment = nil
    address[:address1] = address[:address_1]
    address[:address2] = address[:address_2]
    response = gateway.store(creditcard, :address => address)
    if response.success?
      payment = PaymentCreditCard.create({
        :customer => order.customer,
        :address => address,
        :name => creditcard.name,
        :display_number => creditcard.display_number,
        :billing_id => response.params['billingid']
      })
    end
    [payment, response]
  end
  
  def revokable?
    billing_id
  end
  def useable?
    revokable? or creditable?
  end

  def fee
    2.5
  end
  
  def revoke!
    response = self.class.gateway.unstore(billing_id)
    if response.success?
      self.billing_id = nil
      save!
    else
      raise "Unable to revoke: #{response.inspect}"
    end
  end
  
  def self.message_from(data)
    return '' unless data
    status = case data["status"]
    when "decline"
      return ActiveMerchant::Billing::TrustCommerceGateway::DECLINE_CODES[data["declinetype"]]
    when "baddata"
      return ActiveMerchant::Billing::TrustCommerceGateway::BADDATA_CODES[data["error"]]
    when "error"
      return ActiveMerchant::Billing::TrustCommerceGateway::ERROR_CODES[data["errortype"]]
    else
      return "The transaction was successful"
    end
  end
  
private
  def store_error(order, response, comment)
    PaymentError.create({
      :method => self,
      :order => order,
      :amount => Money.new(0),
      :comment => comment,
      :data => response.params
    })
  end
  
public
  def charge(order, amount, comment)
    logger.info("CreditCard Charge: #{order.id} = #{amount} for #{id}")
    raise "No Billing ID" unless billing_id
    response = self.class.gateway.purchase(amount, billing_id)
    
    if response.success?
      super order, amount, comment, { :id => response.params["transid"] }
    else
      store_error(order, response, comment)
    end
  end

  def refundable?; true; end
  def credit_to(transaction)
    @transaction = transaction
  end
  def creditable?
    @transaction
  end
  
  def credit(order, amount, comment, charge_transaction)
    logger.info("CreditCard Credit: #{order.id} = #{amount} for #{id} : #{charge_transaction.id}")
    response = self.class.gateway.credit(amount, charge_transaction.data[:id])
    if response.success?
      logger.info("Response: #{response.inspect}")
      super order, amount, comment, { :id => response.params["transid"] }
    else
      store_error(order, response, comment)
    end    
  end
end

class PaymentACHCheck < OnlineMethod
  def type_name
    "ACH Check"
  end
  
  def has_name?
    true
  end

  def has_number?
    true
  end
end

class PaymentCheck < PaymentMethod
  before_create :setup_vals
  def setup_vals
    self.name = type_name
    self.display_number = ''
  end

  def revokable?; false; end
  def useable?; transactions.empty?; end
  def refundable?; false; end

  def has_name?; nil; end
  def has_number?; false; end
end

class PaymentSendCheck < PaymentCheck
  def type_name; "Mailed Check"; end
  
  def type_notes
    %q(Please mail check to:
Mountain Xpress Promotions, LLC
954 E. 2nd Ave, Ste 206
Durango, CO. 81301)
  end
end

class PaymentRefundCheck < PaymentCheck
  def type_name; "Refund Check"; end

  def creditable?; true; end
end
