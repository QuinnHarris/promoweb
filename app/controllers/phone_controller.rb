class PhoneController < ActionController::Base
  def suppliers

  end

  def customers
    @customers = Customer.find(:all, :include => :orders,
                  :conditions => "NOT orders.closed AND customers.person_name != ''",
                  :order => 'orders.id DESC',
                               :limit => 100)

    render :layout=>false
  end

  def customer
    @customer = Customer.find(params[:id])

    render :layout=>false
  end



  def current
    user = User.find_by_login(params[:id])
    order = user.current_order
    @customer = order.customer

    @list = order.suppliers.collect do |supplier|
      [supplier.name, supplier.phone]
    end.sort_by { |n, p| n }

    render :action => 'customer', :layout=>false
  end

  def incoming
    unless params[:number] and params[:number].length >= 3
      @lines = ['-- Bad Caller ID --',
                params[:name],
                params[:number]]

      return
    end

    user = User.find_by_login(params[:id])
    user.update_attributes!(:incoming_phone_number => params[:number],
                            :incoming_phone_name => params[:name],
                            :incoming_phone_time => Time.now)

    number = params[:number].gsub(/^1/,'')

    customer = Customer.find(:first,
                             :conditions => ['substring(regexp_replace(phone, \'^1|[^0-9]\', \'\', \'g\') from 1 for 10) = ?', number],
                             :order => 'id DESC')
    if customer
      @lines = [(params[:name] and params[:name].include?('NEW')) ? 
                'DIALED NEW CUSTOMER' : '----- Customer -----',
                customer.company_name,
                customer.person_name]
      orders = customer.orders.find(:all, :conditions => 'NOT closed').collect { |o| o.id }
      @lines << 'Orders: ' + orders.join(',') unless orders.empty?
      return
    end

    area_code = number[0...3].to_i

    pages = PageAccess.find_by_sql("SELECT session_access_id, address, MAX(id) as max FROM " +
                                     "(SELECT * FROM page_accesses WHERE " +
                                     "page_accesses.created_at > (NOW() - '1 days'::interval)) AS sub " +
                                   "GROUP BY session_access_id, address " +
                                   "ORDER BY max DESC LIMIT 200")
    unless pages.empty?
      city_states = []
      pages = pages.find_all do |page|
        begin
          if gi = GEOIP[page.address] and gi.area_code == area_code
            city_states << "#{gi.city} #{gi.region}"
            true
          end
        rescue Net::GeoIP::RecordNotFoundError => e
          false
        end
      end

      products = pages.collect do |page|
        access = PageAccess.find(:all, :conditions => { :controller => 'products', :action => 'main', :session_access_id => page.session_access_id },
                                 :order => 'id DESC')
        Product.find(access.collect { |a| a.action_id })
      end.flatten.uniq
      
      unless products.empty?
        @lines = ["(#{area_code}) #{city_states.uniq.join(', ')}"[0...20]]
        @lines << "DIALED EXISTING CUST" if params[:name] and params[:name].include?('EXIST')
        products[0...(5-@lines.length)].each do |product|
          @lines << "#{product.id} #{product.name}"[0...20]
        end

        return
      end
    end

    # Default
    @lines = ['-- Unkown Caller ---',
              case params[:name]
                when /^NEW/
                ' Dial NEW Customer'
                when /^EXIST/
                ' Dial EXISTING Cust'
                else
                ' DIRECT to Extention'
              end,
              ' ',
              params[:name],
              params[:number] || ' ']
  end

  def prov
    @phone = Phone.find_by_identifier(params[:id])
    @user = @phone.user
  end

  def polycom
    user = User.find_by_login(params[:id])
    order = user.current_order
    @customer = order.customer

    @list = order.suppliers.collect do |supplier|
      [supplier.name, supplier.phone]
    end.sort_by { |n, p| n }

    @customers = Customer.find(:all, :include => :orders,
                  :conditions => "NOT orders.closed AND customers.person_name != ''",
                  :order => 'orders.id DESC',
                               :limit => 10)

    @customers = [@customer] + (@customers - [@customer])
  end

  def polycom_idle
    user = User.find_by_login(params[:id])
    su = user.permissions.find(:first, :conditions => { :order_id => nil, :name => 'Super' })

    @new_orders = Order.count(:include => :customer,
                :conditions => "NOT orders.closed AND orders.user_id IS NULL AND customers.person_name != ''")

    @recent_customer_tasks = OrderTask.find(:all, :include => { :object => :customer },
      :order => :order_id, :conditions =>
      "order_tasks.user_id IS NULL AND " + # Customer executed Task
      "(order_tasks.order_id, order_tasks.created_at) IN " +
        "(SELECT id, max(created_at) FROM " + 
          "((SELECT orders.id, order_tasks.created_at " +
              "FROM order_tasks JOIN orders ON order_tasks.order_id = orders.id " +
              "WHERE NOT orders.closed AND orders.user_id #{su ? ' IS NOT NULL' : " = #{user.id}"} AND order_tasks.type NOT IN ('VisitArtworkOrderTask')) " +
          "UNION (SELECT orders.id, order_item_tasks.created_at " +
                   "FROM order_item_tasks JOIN order_items ON order_item_tasks.order_item_id = order_items.id JOIN orders ON order_items.order_id = orders.id " +
                   "WHERE NOT orders.closed AND orders.user_id IS NOT NULL)) AS sub GROUP BY id)")

  end

  def polycom_notify
    #PolycomIPPhone
    #  IncomingCallEvent
    #    CalledPartyNumber => "sip:a46f22acead469c9@216.246.9.251"
    #    CalledPartyName => "Quinn Harris"
    #    PhoneIP => "10.86.201.174"
    #    TimeStamp => "2011-03-06T12:43:16-07:00"
    #    CallingPartyNumber => "sip:+19707595163@216.246.9.251:5061"
    #    CallingPartyName => "WIRELESS CALLER"
    #    MACAddress => "0004f212bd80"

    event_params = params['PolycomIPPhone']['IncomingCallEvent']
    /^sip:\+?(\d+)\@/ === event_params['CallingPartyNumber']
    number = $1
    return unless number.length >= 7

    user = User.find_by_login(params[:id])
    user.update_attributes!(:incoming_phone_number => number,
                            :incoming_phone_name => event_params['CallingPartyName'],
                            :incoming_phone_time => Time.now)
  end

  
  # XML Directory for polycoms
  def contacts
    phone = nil
    if /^([0-9a-f]{12})-directory$/ === params[:id]
      phone = Phone.find_by_identifier($1)
    end

    @users = User.find(:all, :conditions => 'extension IS NOT NULL' + (phone ? " AND id <> #{phone.user_id}" : ''))
    @suppliers = Supplier.find(:all, :conditions => 'phone IS NOT NULL', :order => 'name')
  end


  def email_status
    author = TMail::Address.parse(params[:author])
    recipients = params[:recipients].split(',').collect { |r| TMail::Address.parse(r) }
    subject = params[:subject]

    emails = [author, recipients].flatten.find_all { |addr| addr.domain != 'mountainofpromos.com' }

    uri = nil
    texts = []

    emails.find do |addr|
      @supplier = Supplier.find(:first, :conditions => ["lower(po_email) ~ ?", addr.domain.downcase], :order => 'parent_id DESC')
    end
    if @supplier or emails.empty?
      texts << @supplier.name if @supplier
      if /(Q\d{4})/ === subject and
          po = PurchaseOrder.find_by_quickbooks_ref($1)
        @order = po.purchase.order
        @supplier = po.purchase.supplier
        texts << "Order #{@order.id}"
        uri = { :controller => '/admin/orders', :action => :items_edit, :order_id => @order }
      end
    end
    
    unless @supplier
      if /\(#(\d{4,5})\)/ === subject and
          @order = Order.find_by_id($1)
        texts << "ORDER DOESN'T MATCH CUSTOMER EMAIL" unless emails.empty? or emails.find { |a| @order.customer.email_addresses.to_a.find { |b| b.address.downcase.include?(a.address.downcase) } }
        texts << (@order.user_id ? @order.user.name : "UNASSIGNED")
        texts << "Order #{@order.id}"
        uri = { :controller => '/admin/orders', :action => :items_edit, :order_id => @order, :own => true } if @order.user_id.nil?
      else
        customers = emails.collect do |addr|
          Customer.find(:all, :include => :email_addresses, :conditions => ["lower(email_addresses.address) ~ ?", addr.address.downcase], :order => 'customers.id DESC')
        end.flatten

        unless customers.empty?
          texts << "MULTIPLE CUSTOMERS" if customers.length > 1
          orders = customers.collect do |customer|
            ret = customer.orders.find(:all, :conditions => { :closed => false }, :order => 'id')
            ret.empty? ? customer.orders : ret
          end.flatten
          orders.collect { |o| o.user }.uniq.each do |user|
            texts << (user ? user.name : "UNASSIGNED")
          end
          @order = orders.last
        else
          if !emails.empty? && recipients.find { |r| r.address == MAIN_EMAIL }
            texts << "NEW CUSTOMER"
            /M(\d{4,5})/ === subject
            uri = { :controller => '/admin/orders', :action => :new_order, :email => author.address || '', :name => author.name, :product => $1}
          else
            texts << "UNKNOWN"
          end
        end
      end
    end
    

    if @order
      texts << @order.customer.company_name unless @order.customer.company_name.blank?
      texts << @order.customer.person_name
      uri = { :controller => '/order', :action => :status, :order_id => @order } unless uri
    end

    render :json => { :text => texts.join(' - '), :uri => uri && url_for(uri.merge({ :protocol => (RAILS_ENV == "production" ? 'https://' : 'http://') })) }
  end

  Phone
  def unidata
    raise "Unknown name" unless /e1_([0-9a-f]{12})\.ini/ === params[:name]
    @phone = Phone.find_by_identifier($1)
  end

  def directory
    if user_string = params[:user]
      user_int = user_string.to_i
      if user_string == user_int.to_s
        user = User.find_by_direct_phone_number(user_int, :include => :phones)
        @no_internal = user
      else
        user = User.find_by_login(user_string, :include => :phones)
        @no_external = user
      end
    end

    @users = user ? [user] : User.find(:all, :include => :phones,
                                       :conditions => "extension IS NOT NULL")

    @active = @users
  end

  def cdr
    render :inline => ''
  end
end
