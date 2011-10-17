# This controller implements the seven web callback methods for QBWC
# Check qbwc_api.rb file for descriptions of parameters and return values
class QbwcController < ActionController::Base
  acts_as_web_service
  web_service_api QbwcApi
  
  # Fallthrough for non soap request (needed to validate certificate)
  def render_text(a, b)
    render :inline => 'Use with SOAP'
  end
  
  before_filter :set_soap_header

  def log_error(exception)
    return unless logger
    
    ActiveSupport::Deprecation.silence do
      message = "\n#{exception.class} (#{exception.message}):\n"
      message << exception.annoted_source_code.to_s if exception.respond_to?(:annoted_source_code)
#      message << "  " << application_trace(exception).join("\n  ")
      logger.fatal("#{message}\n\n")
    end
  end
  
  def qwc
    qwc = %(
<QBWCXML>
   <AppName>PromoWeb</AppName>
   <AppID></AppID>
   <AppURL>http#{Rails.env.production? ? 's://www.mountainofpromos.com' : '://10.86.201.144:3000'}/qbwc/api</AppURL>
   <AppDescription>Mountain Xpress Promotions Quickbooks Integration</AppDescription>
   <AppSupport>https://www.mountainofpromos.com/admin/</AppSupport>
   <UserName>mntxpresspromo</UserName>
   <OwnerID>{d9ec2073-2248-45cf-98fe-4788da4aba7#{Rails.env.production? ? 'a' : 'b'}}</OwnerID>
   <FileID>{77c425b3-0e8a-4dcd-b7a4-679d3e3e385#{Rails.env.production? ? '6' : '0'}}</FileID>
   <QBType>QBFS</QBType>
   <Style>RPC</Style>
   <Scheduler>
      <RunEveryNMinutes>15</RunEveryNMinutes>
   </Scheduler>
</QBWCXML>
)
    send_data qwc, :filename => 'promoweb.qwc'
  end
  
  @@ticket = 'cohtuwei8ahGei'

  # --- [ QBWC version control ] ---
  # Expects:
  #   * string strVersion = QBWC version number
  # Returns string: 
  #   * NULL or <emptyString> = QBWC will let the web service update
  #   * "E:<any text>" = popup ERROR dialog with <any text>, abort update and force download of new QBWC.
  #   * "W:<any text>" = popup WARNING dialog with <any text>, and give user choice to update or not.  
  def clientVersion(version)
    nil # support any version
  end
  
  # --- [ QBWC version control ] ---
  # Expects:
  #   * string strVersion = QBWC version number
  # Returns string: 
  #   * a message string describing the server version and any other information that you want your user to see.
  def serverVersion(ticket)
    "1.2"
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
  def authenticate(username, password)
    if username != 'mntxpresspromo' and
       password != 'Mi0meeref4ium0'
       logger.error("QBWC: Invalid Username Password: #{username} - #{password}")
      return ['', 'nvu']
    end
    [@@ticket, '' ]
  end

  # --- [ To facilitate capturing of QuickBooks error and notifying it to web services ] ---
  # Expects: 
  #   * string ticket  = A GUID based ticket string to maintain identity of QBWebConnector 
  #   * string hresult = An HRESULT value thrown by QuickBooks when trying to make connection
  #   * string message = An error message corresponding to the HRESULT
  # Returns string:
  #   * "done" = no further action required from QBWebConnector
  #   * any other string value = use this name for company file
  def connectionError(ticket, hresult, message)
    'done'
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
    [Supplier, qb_condition(Supplier), 10],
    [Product, qb_condition(Product) + " AND products.name != ''", 200],
    [DecorationTechnique, '( quickbooks_at IS NULL AND quickbooks_id IS NULL )', 100],
    [Customer, qb_condition(Customer) + " AND customers.person_name != ''", 25, :orders],
    [Order, qb_condition(Order) + " AND customers.quickbooks_id IS NOT NULL", 5, :customer],
    [Invoice, qb_condition(Invoice), 1, :order],
    [PurchaseOrder, qb_condition(PurchaseOrder), 1, { :purchase => { :items => :order } }],
    [Bill, qb_condition(Bill), 1, { :purchase => { :items => :order } }],
    [PaymentTransaction, "payment_transactions.quickbooks_id IS NULL AND payment_transactions.type != 'PaymentError'", 10, :method]
  ]
  
  def self.objects
    @@objects.collect { |o| o.first }
  end

  @@qb_list_id = {
    'VendorType-Suppliers' => '80000005-1294361921',
    'JobType-Open' => '80000003-1294367720',
    'JobType-Closed' => '80000004-1294367726',
    'Item-Decorations' => '80000003-1294366227',
    'Item-Products' => '80000002-1294366098',
    'Account-Checking' => '80000005-1294361798',
    'Account-Sales' => '8000000A-1294361921',
    'Account-COG' => '8000000D-1294361921',
    'Class' => '80000001-1294531601',
    'Class-PPC' => '80000002-1294531612'
  }.freeze

  # --- [ Facilitates web service to send request XML to QuickBooks via QBWC ] ---
  # Expects:
  #   * int qbXMLMajorVers
  #   * int qbXMLMinorVers
  #   * string ticket
  #   * string strHCPResponse 
  #   * string strCompanyFileName 
  #   * string Country
  #   * int qbXMLMajorVers
  #   * int qbXMLMinorVers
  # Returns string:
  #   * "any_string" = Request XML for QBWebConnector to process
  #   * "" = No more request XML
  def sendRequestXML(ticket, hpc_response, company_file_name, country, qbxml_major_version, qbxml_minor_version)
    return "" unless ticket == @@ticket
    @qb_list_id = @@qb_list_id
    @@objects.each do |klass, condition, limit, include|
      list = klass.find(:all, :include => include, :conditions => condition, :order => "#{klass.table_name}.id", :limit => limit)
      unless list.empty?
        klass.update_all("quickbooks_at = 'infinity'", ["id IN (?)", list.collect { |r| r.id }])
        instance_variable_set("@#{klass.table_name}", list)
        str = render_to_string(:layout => false, :action => 'sendRequest')
        logger.info("Request Response: <<<")
        logger.info(str)
        logger.info("Request Response: >>>")
        return str
      end
    end
    
    logger.info("XXXX NO QUICKBOOKS UPDATES XXXX")
    
    return ''    
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
        at = Time.now.utc unless !valid or node.name.include?('Query')
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
  def receiveResponseXML(ticket, response, hresult, message)
    return -1 unless ticket == @@ticket
    
    logger.info("receiveResponse: #{ticket}, #{hresult}, #{message}")
    root = REXML::Document.new(response).root
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
    
    update_row(root, %w(ReceivePayment Check), 'TxnID') do |node, id, status|
      PaymentTransaction
    end
    
    return 100 if @dont_repeat

    @@objects.each do |klass, condition, limit, include|
      return 1 if klass.count(:include => include, :conditions => condition) != 0
    end
    
    100 # Signal done - no more requests are needed.
  end

  # --- [ Facilitates QBWC to receive last web service error ] ---
  # Expects:
  #   * string ticket
  # Returns string:
  #   * error message describing last web service error
  def getLastError(ticket)
    #    'An error occurred'
    nil
  end

  # --- [ QBWC will call this method at the end of a successful update session ] ---
  # Expects:
  #   * string ticket 
  # Returns string:
  #   * closeConnection result. Ex: "OK"
  def closeConnection(ticket)
    'OK'
  end
  
  private
    
    # The W3C SOAP docs state (http://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383528):
    #   "The SOAPAction HTTP request header field can be used to indicate the intent of
    #    the SOAP HTTP request. The value is a URI identifying the intent. SOAP places
    #    no restrictions on the format or specificity of the URI or that it is resolvable.
    #    An HTTP client MUST use this header field when issuing a SOAP HTTP Request."
    # Unfortunately the QBWC does not set this header and ActionWebService needs 
    # HTTP_SOAPACTION set correctly in order to route the incoming SOAP request.
    # So we set the header in this before filter.
    def set_soap_header
      if request.env['HTTP_SOAPACTION'].blank? || request.env['HTTP_SOAPACTION'] == %Q("")
        xml = REXML::Document.new(request.raw_post)
        element = REXML::XPath.first(xml, '/soap:Envelope/soap:Body/*')
        request.env['HTTP_SOAPACTION'] = element.name if element
      end
    end

    # Simple wrapping helper
    def wrap_qbxml_request(body)
      r_start = <<-XML
<?xml version="1.0" ?>
<?qbxml version="7.0" ?>
<QBXML>
  <QBXMLMsgsRq onError="continueOnError">
XML
      r_end = <<-XML
  </QBXMLMsgsRq>
</QBXML>
XML
      r_start + body + r_end
    end
end
