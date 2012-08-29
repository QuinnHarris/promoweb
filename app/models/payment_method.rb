module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SkipJackGateway
      def authorize(money, creditcard, options = {})
        requires!(options, :order_id, :email)
        post = {}
        add_order_number(post, options)
        post[:TransactionAmount] = amount(money)
        add_creditcard(post, creditcard)
        #if status_extended_valid?(options)
          add_invoice(post, options)
          add_address(post, options)
        #end
        add_customer_data(post, options)
        commit(:authorization, post)
      end

      def authorize_change(money, authorization, options = {})
        post = { }
        add_status_change(post, 'AUTHORIZE', authorization, options)
        add_forced_settlement(post, options)
        add_amount(post, money)
        commit(:change_status, post)
      end

      def authorize_additional(money, authorization, options = {})
        post = { }
        add_status_change(post, 'AUTHORIZEADDITIONAL', authorization, options)
        add_forced_settlement(post, options)
        add_amount(post, money)
        commit(:change_status, post)
      end
      
      def capture(money, authorization, options = {})
        post = { }
        add_status_change(post, 'SETTLE', authorization, options)
        add_forced_settlement(post, options)
        add_amount(post, money)
        commit(:change_status, post)
      end

      def void(authorization, options = {})
        post = {}
        add_status_change(post, 'DELETE', authorization, options, false)
        add_forced_settlement(post, options)
        commit(:change_status, post)
      end

      def credit(money, identification, options = {})
        post = {}
        add_status_change(post, 'CREDIT', identification, options)
        add_forced_settlement(post, options)
        add_amount(post, money)
        commit(:change_status, post)
      end

      def status(order_id)
        commit(:get_status, :szOrderNumber => order_id)
      end

      private
      def add_amount(params, money)
        params[:szAmount] = amount(money)
      end

      def status_extended_valid?(options)
        return false if options[:billing_address].blank?
        return false if options[:billing_address][:state].blank?
        return false if options[:shipping_address].blank?
        return false if options[:shipping_address][:state].blank?
        return false if options[:shipping_address][:phone].blank?
        true
      end

      # Should remove  add_status_action and add_transaction_id
      def add_status_change(post, action, transaction, options, extended = true)
        post[:szDesiredStatus] = action
        post[:szTransactionId] = transaction
        post[:szNewOrderNumber] = sanitize_order_id(options[:order_id]) unless options[:order_id].blank?
        
        if extended and status_extended_valid?(options)
          action += 'EX'
          add_invoice(post, options)
          add_address(post, options)
        end
      end

      def add_order_number(post, options)
        post[:OrderNumber] = sanitize_order_id(options[:order_id]) unless options[:order_id].blank?
      end


      def add_invoice(post, options)
        post[:CustomerCode] = options[:customer].to_s.slice(0, 17) unless options[:customer].blank?
        post[:CustomerTax] = options[:tax] unless options[:tax].blank?
        post[:PurchaseOrderNumber] = options[:purchase_order] unless options[:purchase_order].blank?
        post[:InvoiceNumber] = options[:invoice] unless options[:invoice].blank?
        post[:OrderDescription] = options[:description] unless options[:description].blank?
        post[:ShippingAmount] = options[:shipping_amount] unless options[:shipping_amount].blank?
        
        if order_items = options[:items]
          post[:orderstring_lvl3] = post[:OrderString] = order_items.collect do |item|
            %w(sku description cost quantity taxable ignore_avs measure discount extended commodity vat_amount vat_rate alt_amount tax_rate tax_type tax_amount).collect do |name|
              item[name.to_sym].to_s.tr('~','-') + '~'
            end.join + '||'
          end.join
        else
          post[:OrderString] = '1~None~0.00~0~N~||'
        end
      end

      def post_data(action, params = {})
        add_credentials(params, action)
        sorted_params = params.to_a.sort{|a,b| a.to_s <=> b.to_s}.reverse
        list = sorted_params.collect { |key, value| "#{key.to_s}=#{CGI.escape(value.to_s)}" }
        Rails.logger.info("SkipJack POST:\n#{list.join("\n")}")
        list.join("&")
      end

      def commit(action, parameters)
        response = parse( ssl_post( url_for(action), post_data(action, parameters) ), action )

        Rails.logger.info("RESPONSE: #{response.inspect}")
        
        # Pass along the original transaction id in the case an update transaction
        Response.new(response[:success], message_from(response, action), response,
          :test => test?,
          :authorization => parameters[:AuditID] || response[:szTransactionFileName] || parameters[:szTransactionId],
          :avs_result => { :code => response[:szAVSResponseCode] },
          :cvv_result => response[:szCVV2ResponseCode]
                     )
      end
    end
  end
end

class PaymentMethod < ActiveRecord::Base
  belongs_to :customer
  belongs_to :address
  has_many :transactions, :class_name => 'PaymentTransaction', :foreign_key => 'method_id'
  
#  validates_uniqueness_of :display_number, :scope => :customer_id
  
  def creditable?; false; end
  def authorizeable?; false; end
  def type_notes; nil; end

  def revoke!; end;
  def fee; 0.0; end
  def level3?; nil; end
  
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
  def authorizeable?; true; end

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

  def apply_error!(transaction, response, error = nil)
    if error.nil? and response.success? and response.params['StatusResponse'] != 'UNSUCCESSFUL'
      transaction.number = response.authorization
      transaction.auth_code = response.params['AUTHCODE']
      transaction.save!
      yield if block_given?
    else
      transaction.type = 'PaymentError'
      transaction.data = response.params.merge(error)
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

  def gateway_invoice_item(invoice, item)
    if item.respond_to?(:quantity)
      return nil unless item.quantity > 0
      quantity = item.quantity
    else
      quantity = 1
    end
    tax_type = invoice.tax_type
    tax_rate = invoice.tax_rate
    sku = if item.is_a?(OrderItem)
            "M#{item.product_id}"
          else
            item.class.to_s.gsub(/[a-z]/i, '') + (item.id || '').to_s
          end
    common = { :sku => sku,
      :taxable => tax_type ? 'Y' : 'N',
      :vat_amount => '0.00',
      :vat_rate => '0.0',
      :alt_amount => '0.00',
      :tax_rate => '%0.02f' % (tax_rate * 100.0),
      :tax_type => 'TAX1',
      :tax_amount => '0.00',
      :measure => 'Yard',
      :commodity => '7311',
      :discount => '0.00'
    }

    description = item.description.encode('ASCII', :invalid => :replace, :undef => :replace, :replace => '')

    result = []
    price = item.list_price

    unless price.marginal.nil? or price.marginal.zero?
      result << common.merge( :description => description + ' Unit', 
                              :cost => price.marginal,
                              :quantity => quantity )
    end

    unless price.fixed.nil? or price.fixed.zero?
      result << common.merge( :description => description + ' Setup', 
                              :cost => price.fixed,
                              :quantity => 1 )
    end

    result.each do |hash|
      hash.merge!( :extended => (amount = hash[:cost] * hash[:quantity]),
                   :tax_amount => amount * tax_rate )
    end
    result
  end
 
public
  def gateway_options(order, transaction = nil)
    options = {
      :customer => order.customer.id,
      :email => order.customer.email_addresses.first.address,
      :billing_address => gateway_address(order, address),
      :force_settlment => true,

      :shipping_address => gateway_address(order, order.customer.ship_address || order.customer.default_address),
      :purchase_order => order.purchase_order.blank? ? order.id : order.purchase_order.gsub(/[^0-9]/,''),
      :tax => '%0.02f' % (order.tax_rate * 100.0),

      :shipping_amount => order.items.inject(Money.new(0)) { |s, i| i.shipping_price ? (s + i.shipping_price) : s }.to_s
    }
    if level3? and transaction.amount.to_i > 1000 and order.level3?
      invoice = order.invoices.last
      if transaction and transaction.amount == invoice.total_price
        transaction.invoice = invoice
        
        options.merge!(:items => invoice.entries.collect do |entry|
          if entry.is_a?(InvoiceOrderItem)
            [gateway_invoice_item(invoice, entry.order_item)] +
              entry.sub_items.collect do |sub|
              gateway_invoice_item(invoice, sub)
            end
          else
            gateway_invoice_item(invoice, entry)
          end
        end.flatten.compact)

        logger.info("Items: #{options[:items].inspect}")
      end
    end
    options
  end

  # Stores as a preauth for $1
  def self.store(order, creditcard, address, amount = Money.new(1.0))
    payment = PaymentCreditCard.where(:customer_id => order.customer.id, :name => creditcard.name, :display_number => creditcard.last_digits, :sub_type => creditcard.type).order('id DESC').first

    payment_new = nil
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
      payment_new = true
    end

    transaction = payment.authorize_record(order, amount)

    response = gateway(type).authorize(amount, creditcard,
                                       payment.gateway_options(order, transaction)
                                         .merge(:order_id => transaction.id))
    if response.success?
      transaction.number = response.authorization
      transaction.auth_code = response.params['AUTHCODE']
      comment = []
      comment << "CCV: #{response.cvv_result['message']}" unless response.cvv_result['code'] == 'M'
      comment << "AVS: #{response.avs_result['message']}" unless response.avs_result['code'] == 'Y'
      transaction.comment = comment.join(', ')
      transaction.save!
    else
      # Failed, clean up
      transaction.destroy
      payment.destroy if payment_new
    end

    [transaction, response]
  end

  def gateway
    self.class.gateway(billing_id)
  end

  def level3?
    billing_id == 'level3'
  end

  alias :authorize_record :authorize
  def authorize(order, amount, comment)
#    txn = transactions.where("type in ('PaymentAuthorize', 'PaymentCharge')").order('type, created_at DESC').first
    txn = transactions.where(:type => 'PaymentAuthorize').first
    logger.info("CreditCard Authorize: #{order.id} = #{amount} for #{id} from #{txn.inspect}")
    res = gateway.status(txn.id)
    logger.info("Status #{txn.id} : #{res.inspect}")
    transaction = super(order, amount, comment)
    response = gateway.authorize_additional(amount, res.params["TransactionID"], #txn.number,
                                            gateway_options(order, transaction)
                                              .merge(:order_id => transaction.id))
    logger.info("Gateway Response: #{response.inspect}")
    error = nil
    while true
      res = gateway.status(transaction.id)
      logger.info("Status Check: #{res.inspect}")
      if res.params['TransactionStatusCode'] == '15'
        error = nil
      else
        error = res.params
      end
      break unless res.params['TransactionStatusCode'] == '14'
      sleep 0.5
    end
    logger.info("Error: #{error}")
    apply_error!(transaction, response, error)
  end

  def charge(order, amount, comment)
    auth_time = Time.now - ((sub_type == 'american_express') ? 30 : 14).days
    txn = transactions.where(:type => 'PaymentAuthorize').where("amount >= ?", amount.to_i).where("created_at > ?", auth_time).where('active').order("order_id != #{order.id}, id, amount").first

    return authorize(order, amount, comment) unless txn

    logger.info("CreditCard Charge: #{order.id} = #{amount} for #{id} from #{txn.inspect}")
    res = gateway.status(order_number = (txn.order_number || txn.id))
    logger.info("Status #{txn.id} : #{res.inspect}")

    transaction = super(order, amount, comment)
    transaction.order_number = order_number
    response = gateway.capture(amount, res.params["TransactionID"],
                               gateway_options(order, transaction)
                                 .merge(:order_id => transaction.id))
    logger.info("Gateway Response: #{response.inspect}")
    apply_error!(transaction, response) do
      txn.active = false
      txn.save!
    end
  end

  def credit(order, amount, comment, charge_transaction)
    logger.info("CreditCard Credit: #{order.id} = #{amount} for #{id} : #{charge_transaction.id}")
    transaction = super(order, amount, comment)
    res = gateway.status(charge_transaction.order_number || charge_transaction.id)
    logger.info("Status #{charge_transaction.id} : #{res.inspect}")
    response = gateway.credit(amount, res.params['success'] ? res.params["TransactionID"] : charge_transaction.number,
                              gateway_options(order, transaction)
                                 .merge(:order_id => transaction.id))
    logger.info("Gateway Response: #{response.inspect}")
    apply_error!(transaction, response)
  end

  def refundable?; true; end
  def credit_to(transaction)
    @transaction = transaction
  end
  def creditable?
    @transaction || false
  end
  
  
end

class PaymentACHCheck < OnlineMethod
  def type_name
    "Electronic Check"
  end
  
  def has_name?
    nil
  end

  def has_number?
    true
  end

  def useable?; transactions.empty?; end
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
