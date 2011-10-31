module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SkipJackGateway
      MONETARY_CHANGE_STATUSES = ['AUTHORIZE', 'AUTHORIZEADDITIONAL', 'CREDIT', 'SPLITSETTLE', 'SETTLE']

      def authorize_additional(money, authorization, options = {})
        post = { }
        add_status_action(post, 'AUTHORIZEADDITIONAL')
        add_invoice(post, options)
        add_address(post, options)
        add_forced_settlement(post, options)
        add_transaction_id(post, authorization)
        commit(:change_status, money, post)
      end
      
      def capture(money, authorization, options = {})
        post = { }
        add_status_action(post, 'SETTLE')
        add_invoice(post, options)
        add_address(post, options)
        add_forced_settlement(post, options)
        add_transaction_id(post, authorization)
        commit(:change_status, money, post)
      end

      def credit(money, identification, options = {})
        post = {}
        add_status_action(post, 'CREDIT')
        add_invoice(post, options)
        add_address(post, options)
        add_forced_settlement(post, options)
        add_transaction_id(post, identification)
        commit(:change_status, money, post)
      end

      private
      def add_invoice(post, options)
        post[:OrderNumber] = sanitize_order_id(options[:order_id]) unless options[:order_id].blank?
        post[:CustomerCode] = options[:customer].to_s.slice(0, 17) unless options[:customer].blank?
        post[:CustomerTax] = options[:tax] unless options[:tax].blank?
        post[:PurchaseOrderNumber] = options[:purchase_order] unless options[:purchase_order].blank?
        post[:InvoiceNumber] = options[:invoice] unless options[:invoice].blank?
        post[:OrderDescription] = options[:description] unless options[:description].blank?
        post[:ShippingAmount] = options[:shipping_amount] unless options[:shipping_amount].blank?
        
        if order_items = options[:items]
          post[:OrderString] = order_items.collect do |item|
            %w(sku description declared_value quantity taxable ignore_avs measure discount extended commodity vat_amount vat_rate tax_rate tax_type tax_amount).collect do |name|
              item[name.to_sym].to_s.tr('~','-') + '~'
            end.join + '||'
          end.join
        else
          post[:OrderString] = '1~None~0.00~0~N~||'
        end
      end
    end
  end
end

class PaymentMethod < ActiveRecord::Base
  belongs_to :customer
  belongs_to :address
  has_many :transactions, :class_name => 'PaymentTransaction', :foreign_key => 'method_id', :order => "id DESC"
  
#  validates_uniqueness_of :display_number, :scope => :customer_id
  
  def creditable?; false; end
  def type_notes; nil; end

  def revoke!; end;
  def fee; 0.0; end
  
  PaymentTransaction
  def authorize(order, amount, comment = nil)
    PaymentAuthorize.create({
      :method => self,
      :order => order,
      :amount => amount,
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
end

class OnlineMethod < PaymentMethod
  def self.gateway(type = 'normal')
    secrets = YAML.load_file("#{Rails.root}/config/secrets")
    ActiveMerchant::Billing::SkipJackGateway.new(secrets['skip_jack'][Rails.env.to_s][type].symbolize_keys)
  end
end

class PaymentCreditCard < OnlineMethod
  def type_name; "Credit Card"; end
  def has_name?; true; end
  def has_number?; true; end

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
    self.billing_id = nil
    save!
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

  def apply_error!(transaction, response)
    if response.success?
      transaction.number = response.authorization
      transaction.auth_code = response.params['AUTHCODE']
      transaction.save!
    else
      transaction.type = 'PaymentError'
      transaction.data = response.params
      transaction.save!
      transaction = PaymentError.find(transaction.id)
    end
    [transaction, response]    
  end

  def gateway_address(order, address)
    phone_numbers = order.customer.phone_numbers.to_a
    fax_numbers = phone_numbers.find_all { |p| p.name == 'Fax' }

    attr = address.attributes.symbolize_keys
    attr.merge(:zip => attr[:postalcode],
               :phone => (phone_numbers - fax_numbers).first.number,
               :fax => fax_numbers.first && fax_numbers.first.number)
  end
 
public
  def gateway_options(order)
    options = {
      :customer => order.customer.id,
      :email => order.customer.email_addresses.first.address,
      :billing_address => gateway_address(order, address),
      :force_settlment => true
    }
    if level3? and order.level3?
      order.invoices.last

      options.merge!({
        :shipping_address => gateway_address(order, order.customer.ship_address || order.customer.default_address),
        :purchase_order => order.purchase_order.blank? ? order.id : order.purchase_order.gsub(/[^0-9]/,''),
        :tax => '%0.02f' % (order.tax_rate * 100.0),                     
                     })
    end
    options
  end

  # Stores as a preauth for $1
  def self.store(order, creditcard, address, amount = Money.new(1.0))
    payment = PaymentCreditCard.where(:customer_id => order.customer.id, :name => creditcard.name, :display_number => creditcard.last_digits, :sub_type => creditcard.type).order('id DESC').first

    type = %w(visa master).include?(creditcard.type) ? 'level3' : 'normal'
    if payment
      payment.address = address
      payment.billing_id = type
      payment.save!
    else
      payment = PaymentCreditCard.create({
        :customer => order.customer,
        :name => creditcard.name,
        :display_number => creditcard.last_digits,
        :sub_type => creditcard.type,
        :address => address,
        :billing_id => type
                                         })
    end

    transaction = payment.authorize_record(order, amount)

    response = gateway(type).authorize(amount, creditcard,
                                       payment.gateway_options(order)
                                         .merge(:order_id => transaction.id))
    if response.success?
      transaction.number = response.authorization
      transaction.auth_code = response.params['AUTHCODE']
      comment = []
      comment << response.cvv_result['message'] unless response.cvv_result['code'] == 'M'
      comment << response.avs_result['message'] unless response.avs_result['code'] == 'Y'
      transaction.comment = comment.join(', ')
      transaction.save!
    else
      # Failed, clean up
      transaction.destroy
      payment.destroy
    end

    [transaction, response]
  end

  def gateway
    self.class.gateway(billing_id)
  end

  def level3?
    billing_id == 'level3'
  end

  def find_authorize
    transactions.where(:type => 'PaymentAuthorize').where("created_at > ?", Time.now-30.days).order('amount DESC').first
  end

  alias :authorize_record :authorize
  def authorize(order, amount, comment)
    txn = find_authorize
    logger.info("CreditCard Authorize: #{order.id} = #{amount} for #{id} from #{txn.inspect}")
    transaction = super(order, amount, comment)
    response = gateway.authorize_additional(amount, txn.number,
                                            gateway_options(order)
                                              .merge(:order_id => transaction.id))
    apply_error!(transaction, response)
  end

  def charge(order, amount, comment)
    txn = find_authorize
    logger.info("CreditCard Charge: #{order.id} = #{amount} for #{id} from #{txn.inspect}")
    transaction = super(order, amount, comment)
    response = gateway.capture(amount, txn.number,
                               gateway_options(order)
                                 .merge(:order_id => transaction.id))
    apply_error!(transaction, response)
  end

  def credit(order, amount, comment, charge_transaction)
    logger.info("CreditCard Credit: #{order.id} = #{amount} for #{id} : #{charge_transaction.id}")
    transaction = super(order, amount, comment)
    response = gateway.credit(amount, charge_transaction.number,
                              gateway_options(order)
                                 .merge(:order_id => transaction.id))
    apply_error!(transaction, response)
  end

  def refundable?; true; end
  def credit_to(transaction)
    @transaction = transaction
  end
  def creditable?
    @transaction
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
