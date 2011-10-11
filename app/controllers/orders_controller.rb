class ActiveMerchant::Billing::CreditCard
  class ExpiryDate #:nodoc:
    attr_reader :year, :month
    def day
      0
    end
    
    def to_s
      "#{month}/#{year}"
    end
    
    # Kludge to make act like Date for date_select with discard_day
    def change(hash); end
  end
  
  def name=(val)
    @name = val
    @first_name, @last_name = val.split(' ')
  end
  def name
    @name ? @name : "#{@first_name}" + (@last_name ? " #{@last_name}" : '')
  end
end

module OrderModule 
  module ClassMethods
    def def_tasked_action(action, *tasks, &block)
      uri = { :controller => "/#{self.controller_path}", :action => action}
      tasks.each do |task|
        next if task.is_a?(String)
        raise "uri already set #{action} #{task} as #{task.uri} != #{uri.inspect}" if task.uri and task.uri != uri
        task.uri = uri
      end
      instance_variable_set "@#{action}_tasks", tasks
      self.class.send(:attr_reader, "#{action}_tasks")
      define_method action, block if block_given?
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
  end
  
private
  def setup_order
    order_id = params[:order_id]
    order_id = params[:id] if order_id.nil? and (/^\d{4,5}$/ === params[:id])
    order_id = session[:order_id] unless order_id

    if params[:auth]
      customer = Customer.find_by_uuid(params[:auth])
      if order_id
        @order = customer.orders.find_by_id(order_id)
      else
        @order = customer.orders.first
      end
      raise "Can't find order for customer" unless @order
      session[:order_id] = @order.id

      # Redirect without :auth parameter
      redirect_to
      return false
    end

    unless session[:order_id] or session[:user_id]
      # If not logged in
      @order = nil
      if params[:controller].include?('admin')
        redirect_to :controller => '/admin/users', :action => :auth
      else
        render :action => :login
      end
      return false
    end
    
    # Typical customer path
    if order_id
      begin
        @order = Order.includes(:customer, :user).find(order_id)
      rescue ActiveRecord::RecordNotFound
        # Temporary kludge to deal with :id for legacy methods
        @order = Order.find(session[:order_id], :include => [:customer, :user])
      end
      
      # If changing order
      unless session[:user_id]
        old_order = Order.find(session[:order_id])
        if old_order.customer_id != @order.customer_id
          @order = nil
          raise "Order #{session[:order_id]} does not belong to current customer"
        end
      end
    end
    
    session[:order_id] = @order && @order.id if @order

    if @order and @user and @user.current_order_id != @order.id
      User.update_all("current_order_id = #{@order.id}", "id = #{@user.id}")
    end

    # Set Timezone
    session[:tz] = nil if params[:order_id] and session[:order_id] != params[:order_id]
    if !session[:tz] and @order and @order.customer.default_address and @order.customer.default_address.postalcode
      list = Zipcode.find_by_sql(["SELECT z.*, r.name as state "+
                                  "FROM constants.zipcodes z, constants.regions r " +
                                  "WHERE z.region = r.id AND z.country = 229 AND z.zip = ?",
                                  @order.customer.default_address.postalcode[0..4]])
      if list.length == 1
        session[:tz] = list.first.tz_name
      end
    end

    # Set page title
    if @order
      if @user
        @title = "#{(@order.customer.company_name.blank? ? @order.customer.person_name : @order.customer.company_name)[0..18]}|#{params[:action].capitalize}"[0..22]
      else
        @title = "Order #{@order.id} #{params[:action].capitalize}"
      end
    end

    # Check Task Permissions
    tasks_name = "#{params[:action]}_tasks"
    return true unless self.class.respond_to?(tasks_name)
    return true unless tasks = self.class.send(tasks_name)
    needed = tasks.collect { |t| t.is_a?(String) ? t : t.roles }.flatten.uniq
    raise "Permission denied, Tasks: #{tasks}; Needed: #{needed.inspect}; Has: #{@permissions.inspect}" if (needed & @permissions).empty?
    true
  end

  def redirect_to_next(inject = [], params = {})
    next_task = @order.task_next(@permissions, inject) { |t| t.uri && !t.uri[:controller].include?('admin') }
    redirect_to ((next_task and next_task.uri) ? next_task.uri : { :controller => '/orders', :action => :status_page }).merge(:id => @order.id).merge(params)
  end
  
  def task_complete(params, task_class, revokable = [], revoked = true)
    @order.task_complete({ :user_id => session[:user_id],
                           :host => request.remote_ip }.merge(params),
                         task_class, revokable, revoked)
    if @order.user_id.nil? and @user
      @order.user = @user
      @order.save!
    end
  end
  
  def task_request(params = {})
    task_complete(params, RequestOrderTask, [RequestOrderTask, RevisedOrderTask])
  end

  def render_edit(task_params = {}, inject = [])
    if params[:ajax]
      render :inline => ''
    else
      if params[:commit] and params[:commit].index('Submit')
        Order.transaction do
          unless @user and @order.task_completed?(RequestOrderTask)
            task_request({:data => { :email_sent => session[:user_id] ? false : true }})
          end
        end
        
        redirect_to status_order_path(@order), :task => 'RequestOrder'
      else
        redirect_to_next(inject)
      end
    end 
  end
  
  def determine_pending_tasks
    return unless @user

    tasks_ready_all = @order.tasks_allowed(@permissions)

    param_name = "#{params[:action]}_tasks"
    if self.class.respond_to?(param_name)
      tasks = self.class.send(param_name)
      availible = tasks_ready_all.find_all do |task|
        tasks.include?(task.class) and task.action_name
      end

      @revokable = @order.tasks_dep.find_all do |task|
        next false unless task.allowed?(@permissions) and task.revokable?
#        next false unless task.status
        tasks.include?(task.class)
      end
    else
      availible = tasks_ready_all
    end

    def process_task(task, complete)
      result = []
      blocked = task.class.blocked(task.object)
      if blocked.nil? and task.auto_complete       
        task.dependants.each do |dep|
          if dep.ready?(complete.collect { |t| t.class })
            result << process_task(dep, complete+[dep])
          end
        end
      end
      return result unless result.empty?
      { :complete => complete,
        :blocked => blocked }
    end

    @tasks = availible.collect do |task|
      process_task(task, [task])
    end.flatten.collect do |hash|
      delegate = (hash[:complete].last.dependants || []).find_all { |t| t.ready?(hash[:complete].collect { |t| t.class }) }
      hash.merge(:delegate => delegate.first)
    end
  end

  # KLUDGE REPLACE THIS CALENDAR
private
  def apply_calendar_header
    #raise "Fix Me"
    @javascripts = (@javascripts || []) + ["calendar", "lang/calendar-en", "calendar-setup"].collect { |n| "/jscalendar-1.0/#{n}" }
    @stylesheets = (@stylesheets || []) + ["calendar-blue"].collect { |n| "/jscalendar-1.0/#{n}"}    
  end
public
end

class OrdersController < AuthenticatedController 
  include OrderModule
  layout 'order'
  
  before_filter :setup_order, :except => [:add, :legacy_redirect]

private
  def set_order_id(order_id)
    session[:order_id] = order_id
    return unless Rails.env.production?

    options = { :session_access_id => session[:ses_id], :order_id => order_id }
    unless OrderSessionAccess.find(:first, :conditions => options)
      OrderSessionAccess.create(options)
    end
  end
public

  # Old Email link URL
  def legacy_redirect
    raise "Legacy without auth" unless params[:auth]
    customer = Customer.find_by_uuid(params[:auth])
    if params[:order_id]
      @order = customer.orders.find_by_id(params[:order_id])
      raise "Can't find order for customer" unless @order
    else
      @order = customer.orders.first
    end
    session[:order_id] = @order.id
    url = { :controller => '/orders', :action => params[:name], :id => @order.id }
    logger.info("Redirect URL: #{url.inspect}")
    redirect_to url
  end

  def index
    if params[:customer_id]
      @customer = Customer.find(params[:customer_id])
      @order = @customer.orders.find(:first, :order => 'id DESC')
    end
  end

  def show
    redirect_to :action => :items
  end

  def_tasked_action :items, ItemNotesOrderTask, 'Art' do
    @address = @order.customer.ship_address ||= Address.new
    
    @static = @order.task_completed?(AcknowledgeOrderTask)
    
    @javascripts = ['autosubmit.js', 'rails.js']   
    
    if params[:order_items]
      OrderItem.transaction do      
        modified = {}
        params[:order_items].each do |id, hash|
          item = @order.items.to_a.find { |i| i.id.to_i == id.to_i }
          raise "Item row not found order_id: #{@order.id} id: #{id}" unless item
          item.update_attributes(hash)
          if item.changed?
            modified.merge!({ item.id => hash })
            item.save!
          end
        end
        
        # Don't revise order on comment changes
        unless @order.task_completed?(ItemNotesOrderTask) or modified.empty?
          task_complete({ :data => modified },
                        ItemNotesOrderTask, [ItemNotesOrderTask, RequestOrderTask, RevisedOrderTask], false)
        end
      end
    
      render_edit
    end
  end
    
  # Order Information
  def_tasked_action :info, InformationOrderTask do    
    @javascripts = ['autosubmit.js']
#    apply_calendar_header

    @static = @order.task_completed?(AcknowledgeOrderTask) && (!@user || !params[:unlock])
    
    if request.post?
      params[:order]['delivery_date(1i)'] = Date.today.year.to_s if params[:order] and params[:order]['delivery_date(1i)'] and params[:order]['delivery_date(1i)'].empty?
      @order.update_attributes(params[:order])
      unless @order.valid?
        @order.save(:validate => false)
        next
      end
      Order.transaction do
        if (@order.changed? or !@order.task_completed?(InformationOrderTask))
          @order.save!
          task_complete({}, InformationOrderTask, [InformationOrderTask, RequestOrderTask, RevisedOrderTask], false)
        end
       end
      render_edit
    end
  end

  def_tasked_action :contact, CustomerInformationTask do
    @no_truste = true

    if @user and params[:customer_id]
      # Reassociate order with customer
      @customer = Customer.find(params[:customer_id], :include => [:ship_address, :default_address])
      @static = true
      @reassoc = true
    else
      @customer = @order.customer
      unless (@naked = @user and @customer.empty?)
        unless @static = (@order.task_completed?(AcknowledgeOrderTask) and !params[:unlock])
          @similar = Customer.find(:first,
            :conditions => ['(' +
                            (@customer.company_name.blank? ? '' : "regexp_replace(lower(company_name), ' |[0-9]', '', 'g') ~ ? OR ") +
                            (@customer.person_name.blank? ? '' : "regexp_replace(lower(person_name), ' |[0-9]', '', 'g') ~ ? OR ") + 
                            "id IN (SELECT customer_id FROM email_addresses WHERE address IN (SELECT address FROM email_addresses WHERE customer_id = #{@customer.id}) ) OR " + 
                            "id IN (SELECT customer_id FROM phone_numbers WHERE number IN (SELECT number FROM phone_numbers WHERE customer_id = #{@customer.id}) ) ) AND " +
                             "id != #{@customer.id}",
                @customer.company_name.blank? ? nil : @customer.company_name.downcase.gsub(/ |[0-9]/,''),
                @customer.person_name.blank? ? nil : @customer.person_name.downcase.gsub(/ |[0-9]/,'')].compact,
            :order => 'id DESC') if session[:user_id]
        end
      end
    end
    
    @default_address = @customer.default_address || (@customer.default_address = Address.new)
    @options = Struct.new(:different).new(@customer.ship_address && @customer.ship_address != @default_address)
    @ship_address = @customer.ship_address || (@customer.ship_address = Address.new)
    
    # Edit Customer
    if params[:customer_id] and params[:customer] and params[:default_address]
      Customer.transaction do 
        @customer.attributes = params[:customer]
        changed = @customer.changed? ||
          @customer.phone_numbers.to_a.find { |p| p.changed? || p.marked_for_destruction? } ||
          @customer.email_addresses.to_a.find { |p| p.changed? || p.marked_for_destruction? }

        @default_address.attributes = params[:default_address]
        if @default_address.changed?
          @default_address.save!
          @customer.shipping_rates_clear!
          changed = true
        end

        if params[:ship_address] and params[:options] and (params[:options][:different] == '1') and
            params[:ship_address].find { |k, v| !v.strip.empty? }
          @ship_address = Address.new if @ship_address == @default_address
          @ship_address.attributes = params[:ship_address]
          if @ship_address.changed?
            @ship_address.save!
            @customer.shipping_rates_clear!
            changed = true
          end
        else
          if @customer.ship_address
            ship_address = @customer.ship_address
            @customer.ship_address = nil
            @customer.save(:validate => false)
            ship_address.destroy unless ship_address == @default_address
            changed = true
          end
        end

        valid = @customer.valid? &&
          !@customer.phone_numbers.to_a.find { |p| !p.valid? } &&
          !@customer.email_addresses.to_a.find { |e| !e.valid? }
        
        if valid
          if changed
            @customer.updated_at_will_change!
            @customer.save!
            @customer.task_complete({ :user_id => session[:user_id],
                                      :host => request.remote_ip,
                                      :data => params[:customer].merge(params[:default_address]) },
                                    CustomerInformationTask, [CustomerInformationTask, RequestOrderTask, RevisedOrderTask], false)
          end
        else
          if changed
            @customer.save(:validate => false) #unless @customer.task_completed?(CustomerInformationTask)
            #@order.task_revoke([CustomerInformationTask, RequestOrderTask, RevisedOrderTask])
          end
          @static = false
          @reassoc = false
        end          

        if @customer.ship_address != @ship_address and @customer.default_address != @ship_address
          @ship_address.destroy
          @customer.shipping_rates_clear!
        end

        @order.save! if changed || @order.apply_sales_tax
        
        if valid
          render_edit
          next
        end
      end
    end
    
    @javascripts = ['autosubmit.js', 'effects.js', 'controls.js', 'rails.js']
    
    # Apply City/State from Zip code
#    if @default_address.postalcode and @default_address.postalcode.length == 5
#       (!@default_address.city or @default_address.city.empty?) and
#       (!@default_address.state or @default_address.state.empty?)
#      if loc = location_from_postalcode(@default_address.postalcode)
#        @default_address.city = loc.city
#        @default_address.state = loc.state
#      end
#    end
  end

private
  def location_from_postalcode(code)
    list = Zipcode.find_by_sql(
     ["SELECT z.*, r.name as state "+
      "FROM constants.zipcodes z, constants.regions r " +
      "WHERE z.region = r.id AND z.country = 229 AND z.zip = ?",
     code[0..4]])
    if list.length == 1
      session[:tz] = list.first.tz_name
      list.first
    else
      nil
    end
  end
public  
  def location_from_postalcode_ajax
    if loc = location_from_postalcode(params[:postalcode])
      render :inline => "$('#{params[:type]}_city').value = '#{loc.city}';" + 
                        "$('#{params[:type]}_state').value = '#{loc.state}';"
    else
     render :inline => ""
    end
  end
  
  # Artwork
  def_tasked_action :artwork, VisitArtworkOrderTask, ArtOverrideOrderTask, ArtReceivedOrderTask, ArtDepartmentOrderTask, ArtPrepairedOrderTask, ArtSentItemTask, ArtExcludeItemTask do

    @artwork = Artwork.new
    groups = @order.customer.artwork_groups
    @artwork_groups = groups.find_all { |g| !g.decorations_for_order(@order).empty? }
    groups -= @artwork_groups
    unused_groups = groups.find_all { |g| g.order_item_decorations.empty? }
    @artwork_groups << nil unless @artwork_groups.empty? or unused_groups.empty?
    @artwork_groups += unused_groups
    groups -= unused_groups
    @artwork_groups << "Artwork from other orders" unless groups.empty?
    @artwork_groups += groups

    @static = @order.task_completed?(ArtAcknowledgeOrderTask) && (!@user || !params[:unlock])

    @order_item_decorations = @order.items.collect { |oi| oi.decorations.find(:all, :conditions => { 'artwork_group_id' => nil }) }.flatten
    @upload_id = Time.now.to_i.to_s
    
    @stylesheets = ['orders']
    @javascripts = ['autosubmit.js', 'rails.js'] #, 'upload_progress.js']
    @javascripts += ['effects.js', 'dragdrop.js'] if @user
    apply_calendar_header if @user

    task_complete({}, VisitArtworkOrderTask) unless @order.closed or @order.task_completed?(VisitArtworkOrderTask)
    
    next unless session[:user_id]
    
    determine_pending_tasks
    
    @permited = @order.permissions.find_all_by_name(self.class.artwork_tasks.collect { |t| t.roles }.flatten.uniq,
      :include => :user)
  end
  
private
  def get_ready(waiting, current, done)
    remain = []
    ret = waiting.find_all do |t|
      if t.ready_given?(current + done)
        enabled = t.status || (session[:user_id] and t.admin)
        t.set_cols(enabled, current)
        remain << t unless enabled
        true
      end
    end
    ret += get_ready(waiting - ret, current + remain, done) unless remain.empty?
    ret
  end
public
  
  def status_page
    Admin::OrdersController
    if session[:user_id]
      apply_calendar_header
      @javascripts << 'rails.js'
    end
    
    unless @order
      @order = Order.new
      @order.customer = Customer.new
    end
    
    # Add temp order_item to make status page right
    if @order.items.empty?
      order_item = OrderItem.new
      order_item.order = @order
      order_item.product = Product.find(8248)
      @order.items.target = [order_item]
    end

    determine_pending_tasks
           
    current = []
    done = []
    @list = @order.tasks_dep
    waiting = @list.dup # @waiting.dup
    
    cols_table = 1
    
    @display = []
    
    item_headers = (@order and @order.items.count > 0)
    
    while true
#      logger.info("Current: #{current.collect { |t| "#{t.class} : #{t.rows},#{t.cols}"}.inspect}")
      
      ready = get_ready(waiting, current, done)
#      logger.info("Ready: #{ready.collect { |t| t.class }.inspect}")
      break if ready.empty?
      
      complete = ready.collect { |t| t.depends_on }.flatten
#      logger.info("Complete: #{complete.collect { |t| t.class }.inspect}")
      current -= complete
      current.each { |t| t.inc_rows if t.visible }
      current += ready
      waiting -= ready
      
      done += complete
      
      disp = ready.find_all { |t| t.visible }
#      logger.info("Display #{disp.collect { |t| t.class }.inspect}")

      if item_headers and disp.first.is_a?(OrderItemTask)
        item_headers = nil
        @display << disp.collect { |t| HeaderItemTask.new(t) }
      end

      @display << disp unless disp.empty?
      
#      logger.info("CurrentX: #{current.collect { |t| "#{t.class} : #{t.rows},#{t.cols}"}.inspect}")
      cols_virt = current.find_all { |t| t.visible }.inject(0) { |s, v| s + (v.cols.to_i || 0) }
#      logger.info("Bef: #{cols_table.inspect} #{@cols_mult}  #{cols_virt.inspect}")
      next unless cols_virt > 0
      
      cols_table_new = cols_table.to_i.lcm cols_virt
      if @cols_mult
        if cols_table_new != cols_table
          cols_mult = cols_table_new / cols_table
          ready.each { |t| t.cols /= cols_mult.to_f }
#          logger.info("Expand: #{cols_table_new} #{cols_table} #{cols_virt} #{cols_mult}")
          @cols_mult = cols_mult
        end
      else
        @cols_mult = 1
#        logger.info("INIT")
      end
      cols_table = cols_table_new
      
#      logger.info("Bef: #{cols_table} #{@cols_mult}")
    end
    
    #logger.info(list.inspect)
    render 'status'
  end
  
  def_tasked_action :payment, PaymentInfoOrderTask, PaymentOverrideOrderTask, FirstPaymentOrderTask, FinalPaymentOrderTask do    
    @customer = @order.customer

    @javascripts = ['autosubmit.js', 'rails.js']
    
    if params[:commit]
      render_edit({}, [PaymentInfoOrderTask])
      next
    end
    
    @javascripts << 'admin_orders' if @user
    
    apply_calendar_header
    
    determine_pending_tasks

    @payment_methods = @customer.payment_methods.find(:all, :include => :transactions)
    if @payment_methods.empty?
      @address = @customer.default_address
      @options = Struct.new(:different).new nil
      @credit_card = ActiveMerchant::Billing::CreditCard.new
      next
    elsif @user and params[:txn_id]
      # If this is a refund setup the refund method
      txn_id = Integer(params[:txn_id])
      @payment_methods.each do |method|
        method.transactions.each do |transaction|
          method.credit_to(transaction) if transaction.id == txn_id
        end
      end
    end
  end

  def payment_submit
    render_edit
  end

  def payment_use
    PaymentInfoOrderTask.transaction do
      payment_method = PaymentMethod.find(params[:method_id], :include => :customer)
      raise "Payment not associated with customer" unless @order.customer_id == payment_method.customer_id
      raise "Already have payment info" unless payment_method.billing_id and !@order.task_completed?(PaymentInfoOrderTask)
      
      task_complete({ :data => { :id => payment_method.id } },
                    PaymentInfoOrderTask)
    end
    redirect_to :action => :payment
  end
  
  def payment_remove
    PaymentMethod.transaction do
      payment_method = PaymentMethod.find(params[:method_id], :include => :customer)
      raise "Payment not associated with customer" unless @order.customer_id == payment_method.customer_id

      payment_method.revoke! if payment_method.revokable?

      if payment_method.transactions.empty?
        payment_method.destroy
        if payment_method.address_id != payment_method.customer.default_address_id
          payment_method.address.destroy
        end

        unless payment_method.customer.payment_methods.to_a.find { |m| m.useable? } or @order.task_completed?(FirstPaymentOrderTask)
          @order.task_revoke([PaymentInfoOrderTask])
        end
      end
    end
    redirect_to :action => :payment
  end
    
  def filter_parameters(unfiltered_parameters)
    parameters = unfiltered_parameters.dup
    if unfiltered_parameters['action'] == 'payment_creditcard'
      parameters.delete('credit_card')
    end
    parameters
  end

  def payment_creditcard
    @customer = @order.customer
    @options = Struct.new(:different).new(params[:options] ? (params[:options][:different] == '1') : nil)
    @address = @options.different ? Address.create(params[:address]) : @customer.default_address
    
    return unless params[:credit_card]
  
    @credit_card = ActiveMerchant::Billing::CreditCard.new(params[:credit_card])
    
    # Validate basic info
    return unless @credit_card.valid?
    
    PaymentMethod.transaction do      
      payment, response = PaymentCreditCard.store(@order, @credit_card, @address)
      logger.info("Response: #{response.inspect}")
      unless response.success?
        if %w(baddata error).include?(response.params['status'])
          raise StandardError, "CreditCard Process Error: #{response.params['status']}: #{response.message}: #{response.params.inspect}"
        end
        
        case response.params['declinetype']
          when 'decline'
            @credit_card.errors.add_to_base(response.message)
          when 'call'
            @credit_card.errors.add_to_base(response.message)
          when 'avs'
            @address.errors.add_to_base(response.message)
          when 'cvv'
            @credit_card.errors.add(:verification_value, response.message)
          when 'carderror'
            @credit_card.errors.add(:number, response.message)
          else
            @credit_card.errors.add_to_base("Authorization Failed")
          end
        
        return
      end
      
      task_complete({ :data => { :id => payment.id } },
                    PaymentInfoOrderTask, nil, false)
      flash[:notice] = "Successfully added Credit Card"
    end
    
    redirect_to :action => :payment, :order_id => @order, :task => 'PaymentInfoOrder'
  end
  
  def payment_sendcheck
    @customer = @order.customer
    @address = @customer.default_address
  
    PaymentMethod.transaction do
#      if PaymentSendCheck.find_by_customer_id(@order.customer_id)
#        raise "Send Check Payment method can only be added once per customer"
#      end
    
      klass = PaymentSendCheck
      klass = PaymentRefundCheck if @user && params[:refund]
      payment = klass.create({
        :customer => @customer,
        :address => @address,
      })
      
#      task_complete({ :data => { :id => payment.id } },
#                    PaymentInfoOrderTask, nil, false)
    end
    
    redirect_to :action => :payment, :order_id => @order
  end
   
  def_tasked_action :acknowledge_order, AcknowledgeOrderTask do
    @order_task = OrderTask.new(params[:order_task])

    @javascripts = ['rails.js'] if @user

    next unless params[:commit]
    
    Order.transaction do
      if params[:commit].include?('Reject')
        @order.task_revoke([AcknowledgeOrderTask, RevisedOrderTask], { :customer_comment => @order_task.comment })
        redirect_to :action => :status
      elsif params[:commit].include?('Acknowledge')
        (invoice = @order.generate_invoice) && invoice.save!
        task_complete({:data => { :email_sent => !params[:commit].include?('Without Email'), :customer_comment => @order_task.comment }}, AcknowledgeOrderTask)
        if @order.total_item_price.zero? and !@order.task_completed?(PaymentInfoOrderTask)
          task_complete({}, PaymentNoneOrderTask)
        end
        redirect_to :task => 'AcknowledgeOrder'
      else
        redirect_to_next [AcknowledgeOrderTask]
      end
    end
  end

  def invoices
    @static = true
    respond_to do |format|
      format.html
      format.pdf do
        render :pdf => "Order #{@order.id} Invoice", :layout => 'print'
      end
    end
  end
  
  def_tasked_action :acknowledge_artwork, ArtAcknowledgeOrderTask do
    @customer = @order.customer   
    @order_task = OrderTask.new(params[:order_task])

    next unless params[:commit]

    Order.transaction do
      if params[:commit].include?('Reject')
        task = @order.task_revoke([ArtAcknowledgeOrderTask, ArtPrepairedOrderTask], { :customer_comment => @order_task.comment })
        redirect_to :action => :status
      elsif params[:commit].include?('Accept')
        task_complete({ :data => { :email_sent => !params[:commit].include?('Without Email'), :customer_comment => @order_task.comment } }, ArtAcknowledgeOrderTask)
        redirect_to :task => 'ArtAcknowledgeOrder'
      else
        redirect_to_next [ArtAcknowledgeOrderTask]
      end
    end
  end

#  def_tasked_action :review, ReviewOrderTask do
  def review
    unless params[:commit]
      @order_task = @order.task_find(ReviewOrderTask)
      company_person = !@order.customer.company_name.strip.empty?
      @order_task = ReviewOrderTask.new(:show_products => true, :show_company => company_person, :show_person => !company_person) unless @order_task
    else
      @order_task = task_complete(params[:order_task], ReviewOrderTask)
      expire_fragment(:controller => 'categories', :action => 'home')
    end
  end
end
