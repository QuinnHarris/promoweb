class QbwcRouter < WashOut::Router
  # The W3C SOAP docs state (http://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383528):
  #   "The SOAPAction HTTP request header field can be used to indicate the intent of
  #    the SOAP HTTP request. The value is a URI identifying the intent. SOAP places
  #    no restrictions on the format or specificity of the URI or that it is resolvable.
  #    An HTTP client MUST use this header field when issuing a SOAP HTTP Request."
  # Unfortunately the QBWC does not set this header and ActionWebService needs 
  # HTTP_SOAPACTION set correctly in order to route the incoming SOAP request.
  # So we set the header in this before filter.
  def call(env)
    if env['HTTP_SOAPACTION'].blank? || (env['HTTP_SOAPACTION'] == %Q(""))
      if env['action_dispatch.request.request_parameters']
        env['HTTP_SOAPACTION'] = env['action_dispatch.request.request_parameters']['Envelope']['Body'].keys.last.dup
      else
        return Admin::SystemController.action(:blank).call(env)
      end
    end

    super env
  end
end

# This controller implements the seven web callback methods for QBWC
class QbwcController < ActionController::Base
  include WashOut::SOAP

  # Fallthrough for non soap request (needed to validate certificate)
#  def render_text(a, b)
#    render :inline => 'Use with SOAP'
#  end

#  def log_error(exception)
#    return unless logger
#    
#    ActiveSupport::Deprecation.silence do
#      message = "\n#{exception.class} (#{exception.message}):\n"
#      message << exception.annoted_source_code.to_s if exception.respond_to?(:annoted_source_code)
#      message << "  " << application_trace(exception).join("\n  ")
#      logger.fatal("#{message}\n\n")
#    end
#  end
    
  @@ticket = 'cohtuwei8ahGei'

  # --- [ QBWC version control ] ---
  # Expects:
  #   * string strVersion = QBWC version number
  # Returns string: 
  #   * NULL or <emptyString> = QBWC will let the web service update
  #   * "E:<any text>" = popup ERROR dialog with <any text>, abort update and force download of new QBWC.
  #   * "W:<any text>" = popup WARNING dialog with <any text>, and give user choice to update or not.
  soap_action 'clientVersion', :args => { :strVersion => :string }, :return => :string
  def clientVersion
    render :soap => nil # support any version
  end
  
  # --- [ QBWC version control ] ---
  # Expects:
  #   * string strVersion = QBWC version number
  # Returns string: 
  #   * a message string describing the server version and any other information that you want your user to see.
  soap_action 'serverVersion', :args => { :strVersion => :string }, :return => :string
  def serverVersion
    render :soap => "1.2"
  end

  # --- [ Authenticate web connector ] ---
  # Expects: 
  #   * string strUserName = username from QWC file
  #   * string strPassword = password
  # Returns string[2]: 
  #   * string[0] = ticket (guid)
  #   * string[1] =
  #       - empty string = use current company file
  #       - "none" = no further request/no further action required
  #       - "nvu" = not valid user
  #       - any other string value = use this company file    
  soap_action 'authenticate', :args => { :strUserName => :string, :strPassword => :string }, :return => { :item => :string }
  def authenticate
    if params[:strUserName] != 'mntxpresspromo' and
       params[:strPassword] != 'Mi0meeref4ium0'
      logger.error("QBWC: Invalid Username Password: #{params[:strUserName]} - #{params[:strPassword]}")
      render :locals => { :ticket => '', :status => 'nvu' }, :content_type => 'text/xml'
      return
    end
    logger.info("QBWC: authenticated")
    render :locals => { :ticket => @@ticket, :status => '' }, :content_type => 'text/xml'
  end

  # --- [ To facilitate capturing of QuickBooks error and notifying it to web services ] ---
  # Expects: 
  #   * string ticket  = A GUID based ticket string to maintain identity of QBWebConnector 
  #   * string hresult = An HRESULT value thrown by QuickBooks when trying to make connection
  #   * string message = An error message corresponding to the HRESULT
  # Returns string:
  #   * "done" = no further action required from QBWebConnector
  #   * any other string value = use this name for company file
  soap_action 'connectionError', :args => { :ticket => :string, :hresult => :string, :message => :string }, :return => [:string]
  def connectionError
    render :soap => 'done'
  end
  
  # quickbooks_id = valid if object exists in quickbooks in any state
  # quickbooks_sequence = valid unless object is in error state
  # quickbooks_at = valid if object is up to date, infinity when updating or failed updating, -infinity to force update when quickbooks_id is valid
  def self.qb_condition(klass)
    table_name = klass.table_name
    "( ( (#{table_name}.quickbooks_at IS NULL) AND (#{table_name}.quickbooks_id IS NULL) ) OR " +     # Add Item
    "( (#{table_name}.quickbooks_at IS NOT NULL) AND (#{table_name}.updated_at >= #{table_name}.quickbooks_at) ) )" # Mod Item
  end
  
  @@objects = [
    [Supplier, qb_condition(Supplier)],
    [Product, qb_condition(Product) + " AND products.name != ''"],
    [DecorationTechnique, '( quickbooks_at IS NULL AND quickbooks_id IS NULL AND parent_id IS NULL )'],
    [Customer, qb_condition(Customer) + " AND customers.person_name != ''", :orders],
    [Order, qb_condition(Order) + " AND customers.quickbooks_id IS NOT NULL", :customer],
    [Invoice, qb_condition(Invoice), :order, 5],
    [PurchaseOrder, qb_condition(PurchaseOrder), { :purchase => { :items => :order } }, 5],
    [Bill, qb_condition(Bill), { :purchase => { :items => :order } }, 5],
    [PaymentTransaction, "payment_transactions.quickbooks_id IS NULL AND (payment_transactions.quickbooks_at IS NULL OR payment_transactions.quickbooks_at < payment_transactions.created_at) AND payment_transactions.type IN ('PaymentCharge', 'PaymentCredit', 'PaymentBitCoinAccept')", :method, 10]
  ]
  
  def self.objects
    @@objects.collect { |o| o.first }
  end

  @@qb_list_id = {
    'VendorType-Suppliers' => '80000005-1388431826',
    'JobType-Open' => '80000003-1389477472',
    'JobType-Closed' => '80000004-1389477472',
    'Item-Decorations' => '80000002-1389477472',
    'Item-Products' => '80000003-1389477472',
    'Item-Misc' => '80000004-1389477472',
    'Account-Checking' => '80000025-1389477377',
    'Account-Sales' => '80000006-1388431826',
    'Account-COG' => '8000000B-1388431826',
    'Account-Bitcoin' => '80000027-1389554922',
    'Class' => '80000001-1389477472',
    'Class-PPC' => '80000002-1389477472',
  }.freeze

  # --- [ Facilitates web service to send request XML to QuickBooks via QBWC ] ---
  # Expects:
  #   * string ticket
  #   * string strHCPResponse 
  #   * string strCompanyFileName 
  #   * string Country
  #   * int qbXMLMajorVers
  #   * int qbXMLMinorVers
  # Returns string:
  #   * "any_string" = Request XML for QBWebConnector to process
  #   * "" = No more request XML
  soap_action 'sendRequestXML', :args => { :ticket => :string,
                                           :strHCPResponse => :string,
                                           :strCompanyFileName => :string,
                                           :Country => :string,
                                           :qbXMLMajorVers => :integer,
                                           :qbXMLMinorVers => :integer },
                                :return => :string
  def sendRequestXML
    unless params[:ticket] == @@ticket
      render :soap => ''
      return
    end

    @qb_list_id = @@qb_list_id
    @@objects.each do |klass, condition, include, limit|
      list = klass.find(:all, :include => include, :conditions => condition, :order => "#{klass.table_name}.id", :limit => limit)
      unless list.empty?
        klass.update_all("quickbooks_at = 'infinity'", ["id IN (?)", list.collect { |r| r.id }])
        instance_variable_set("@#{klass.table_name}", list)
        begin
          str = render_to_string(:layout => false, :action => 'sendRequest')
        rescue => boom
          logger.error("BOOM: #{boom.inspect}")
          boom.backtrace.each do |line|
            logger.error("  #{line}")
          end
          raise boom
        end
        logger.info("Request Response: <<<")
        logger.info(str)
        logger.info("Request Response: >>>")
        render :soap => str
        return
      end
    end
    
    logger.info("XXXX NO QUICKBOOKS UPDATES XXXX")

    render :soap => nil
  end

private
  def update_row(root, xml_names, id_element = 'ListID')
    xml_names = [xml_names].flatten
    xpath_str = xml_names.collect { |n| "QBXMLMsgsRs/#{n}AddRs|QBXMLMsgsRs/#{n}ModRs|QBXMLMsgsRs/#{n}QueryRs" }.join('|')
    root.get_elements(xpath_str).each do |node|
      raise "Unknown id : #{node}" unless id = node.attribute('requestID')
      id = Integer(id.value)
      raise "Unknown status" unless status = node.attribute('statusCode')
      listID = sequence = at = nil
      status = status.value
      if (valid = (status == '0')) or status == "3200" # Sequence out of date
        raise "Unknown listID : #{node}" unless listID = node.get_elements(xml_names.collect { |n| "#{n}Ret/#{id_element}" }.join('|')).first
        listID = listID.text
        raise "Unknown sequence" unless sequence = node.get_elements(xml_names.collect { |n| "#{n}Ret/EditSequence" }.join('|')).first  
        sequence = sequence.text
        if valid
          at = Time.now.utc unless node.name.include?('Query')
        else
          at = '-infinity'
        end
      elsif status == '3175'
        at = '-infinity'
        @dont_repeat = true
      end
      
      Order.transaction do
        klass, props = yield node, id, status
        props = {} unless props
        props.merge!({
          :quickbooks_id => listID,
          :quickbooks_sequence => sequence }) if listID
        props.merge!({
          :quickbooks_id => 'INVALID' }) if !listID and !valid and node.name.index('AddRs')
        props.merge!({
          :quickbooks_at => at })
        klass.update_all([props.keys.collect { |col| "#{col} = ?" }.join(',')] + props.values,
                          "id = #{id}")
      end
    end
  end
  
  def update_po_bill(root, klass, qb_type, aspect)
    update_row(root, klass.to_s, 'TxnID') do |node, id, status|
      next klass if status == '3200' or status == '3175'
      
      invoice_txns = node.get_elements("#{klass.to_s}Ret/#{qb_type}LineRet").collect do |line|
        raise "No TXNLineID" unless txn = line.get_elements("TxnLineID").first
        txn.text
      end.flatten
      
      obj = klass.find(id, :include => { :purchase => :items })
      obj.purchase.items.each do |item|
        item.order_item_variants.each do |oiv|
          next if oiv.quantity == 0
          oiv.class.update_all({ "quickbooks_#{aspect}_id" => invoice_txns.shift },
                               { :id => oiv.id })
        end

        price = item.list_cost
        item.class.update_all({ "quickbooks_#{aspect}_id" => invoice_txns.shift },
                              { :id => item.id }) unless price.fixed.nil? or price.fixed.to_i == 0
        
        %w(decorations entries).each do |sub_type|
          item.send(sub_type).each do |sub|
            price = sub.list_cost
            no_marginal = (price.marginal.nil? or price.marginal.to_i == 0)
            no_fixed = (price.fixed.nil? or price.fixed.to_i == 0)
            if ((price.marginal.to_i == 0) or
                (price.fixed.to_i == 0)) and
                no_marginal and no_fixed
              marginal = fixed = invoice_txns.shift
            else
              marginal, fixed = %w(marginal fixed).collect do |a|
                price_part = price.send(a)
                next nil if price_part.nil? or price_part.zero?
                qb_id = invoice_txns.shift
              end
            end
            sub.class.update_all({ "quickbooks_#{aspect}_marginal_id" => marginal,
                                   "quickbooks_#{aspect}_fixed_id" => fixed },
                                 { :id => sub.id })
          end
        end

        if ship_price = item.list_shipping_cost and !ship_price.zero?
          item.class.update_all({ "quickbooks_#{aspect}_shipping_id" => invoice_txns.shift },
                                { :id => item.id })
        end
      end

      obj.purchase.entries.each do |entry|
        entry.class.update_all({ "quickbooks_#{aspect}_id" => invoice_txns.shift },
                               { :id => entry.id })
      end
      
      raise "Txn left over: #{invoice_txns.inspect}" unless invoice_txns.empty?
      
      [klass, { :quickbooks_ref => node.get_elements("#{klass.to_s}Ret/RefNumber").first.text }]
    end
  end

  
public

  # --- [ Facilitates web service to receive response XML from QuickBooks via QBWC ] ---
  # Expects:
  #   * string ticket
  #   * string response
  #   * string hresult
  #   * string message
  # Returns int:
  #   * Greater than zero  = There are more request to send
  #   * 100 = Done. no more request to send
  #   * Less than zero  = Custom Error codes
  soap_action 'receiveResponseXML', :args => { :ticket => :string,
                                               :response => :string,
                                               :hresult => :string,
                                               :message => :string },
                                    :return => :int
  def receiveResponseXML
    unless params[:ticket] == @@ticket
      render :soap => -1
      return
    end
    
    logger.info("receiveResponse: #{params[:ticket]}, #{params[:hresult]}, #{params[:message]}")
    root = REXML::Document.new(params[:response]).root
    logger.info("response parsed")
    
    update_row(root, 'Vendor') { Supplier }

    update_row(root, 'ItemNonInventory') do |node, id, status|
      id < 1000 ? DecorationTechnique : Product    
    end
  
    update_row(root, 'Customer')  do |node, id, status|
      node.get_elements("CustomerRet/Name").first ? Order : Customer
    end
    
    update_row(root, %w(Invoice CreditMemo), 'TxnID') do |node, id, status|
      [Invoice, { :quickbooks_ref => (x = node.get_elements("InvoiceRet/RefNumber|CreditMemoRet/RefNumber").first) ? x.text : nil }]
    end
    
    update_po_bill(root, PurchaseOrder, 'PurchaseOrder', 'po')

    update_po_bill(root, Bill, 'Item', 'bill')
    
    update_row(root, %w(ReceivePayment Check ARRefundCreditCard), 'TxnID') do |node, id, status|
      PaymentTransaction
    end   

    @@objects.each do |klass, condition, include, limit|
      if klass.count(:include => include, :conditions => condition) != 0
        render :soap => 1
        return
      end
    end unless @dont_repeat
    
    render :soap => 100 # Signal done - no more requests are needed.
  end

  # --- [ Facilitates QBWC to receive last web service error ] ---
  # Expects:
  #   * string ticket
  # Returns string:
  #   * error message describing last web service error
  soap_action 'getLastError', :args => { :ticket => :string }, :return => :string
  def getLastError
    #    'An error occurred'
    render :soap => nil
  end

  # --- [ QBWC will call this method at the end of a successful update session ] ---
  # Expects:
  #   * string ticket 
  # Returns string:
  #   * closeConnection result. Ex: "OK"
  soap_action 'closeConnection', :args => { :ticket => :string }, :return => :string
  def closeConnection
    render :soap => 'OK'
  end

end
