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
        raise "uri already set #{action} #{task} as #{uri.inspect}" if task.uri and task.uri != uri
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
    unless request.protocol == "https://" or RAILS_ENV != "production"
      redirect_to :protocol => "https://" 
      return false
    end

#    raise "No session @order" unless @order

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
    tasks = self.class.send(tasks_name)
    needed = tasks.collect { |t| t.is_a?(String) ? t : t.roles }.flatten.uniq
    raise "Permission denied, Tasks: #{tasks}; Needed: #{needed.inspect}; Has: #{@permissions.inspect}" if (needed & @permissions).empty?
    true
  end

  def redirect_to_next(inject = [], params = {})
    next_task = @order.task_next(@permissions, inject) { |t| t.uri && !t.uri[:controller].include?('admin') }
    redirect_to ((next_task and next_task.uri) ? next_task.uri : { :controller => '/order', :action => :status }).merge({:order_id => @order.id}).merge(params)
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
        
        redirect_to :action => :status, :order_id => @order, :task => 'RequestOrder'
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
    @javascripts = (@javascripts || []) + ["calendar", "lang/calendar-en", "calendar-setup"].collect { |n| "/jscalendar-1.0/#{n}" }
    @stylesheets = (@stylesheets || []) + ["calendar-blue"].collect { |n| "/jscalendar-1.0/#{n}"}    
  end
public
end

class OrderController < ApplicationController 
  include OrderModule
  layout 'order'
  
  before_filter :setup_order, :except => [:auth, :logout, :add_item]

private
  def set_order_id(order_id)
    session[:order_id] = order_id
    return unless RAILS_ENV == "production"

    options = { :session_access_id => session[:ses_id], :order_id => order_id }
    unless OrderSessionAccess.find(:first, :conditions => options)
      OrderSessionAccess.create(options)
    end
  end
public

  # To be depreciated
  def auth
    @customer = Customer.find_by_uuid(params[:id], :include => :default_address)
#    location_from_postalcode(@customer.default_address.postalcode)  # Set time zone
    if params[:order]
      @order = @customer.orders.find_by_id(params[:order])
    else
      @order = @customer.orders.first
    end
    set_order_id(@order.id)
    if params[:act]
      redirect_to :action => params[:act], :order_id => @order.id 
    else
      redirect_to_next
    end
  end

  def login
    redirect_to_next
  end
  
  def logout
    session[:order_id] = nil
    redirect_to :controller => 'categories', :action => 'home'
  end

  def add_item
    product = Product.find(params[:product])
    
    quantity = params[:quantity].to_i
    if params[:quantity].empty? or quantity == 0
      render :inline => "Invalid Quantity"
      return
    end
    price_group = PriceGroup.find(params[:price_group])
    technique = DecorationTechnique.find(params[:technique]) unless !params[:technique] or params[:technique] == 'NaN' or params[:technique].empty?
    decoration = Decoration.find(params[:decoration]) unless !params[:decoration] or params[:decoration] == 'NaN' or params[:decoration].empty?
    unit_count = params[:unit_count].to_i != 0 ? params[:unit_count].to_i : nil

    unless params[:variants].blank?
      variant = Variant.find(params[:variants].split(',').first)
    else
      variant = price_group.variants.first if price_group.variants.length == 1
    end
    
    Customer.transaction do
      @customer = @order.customer if @order

      if @user and %w(order customer).include?(params[:disposition])
        @order = nil
        @customer = nil if params[:disposition] == 'customer'
        logger.info("Adding as new #{params[:disposion]}")
      elsif @order and @order.task_completed?(AcknowledgeOrderTask) and (params[:disposion] != 'exist')
        order = @customer.orders.find(:first)
        if @order.id != order.id and !order.task_completed?(AcknowledgeOrderTask)
          @order = order
        else
          logger.info("Creating new order")
          @order = nil
        end
      end

      unless @order
        unless @customer
          @customer = Customer.new({
            :company_name => '',
            :person_name => ''})
          @customer.save(:validate => false)
        end

        @order = @customer.orders.create
        @order.save!
      end

      item_params = {
        :product_id => product.id,
        :price_group_id => price_group.id
      }

      if technique
        if technique.id == 1
          blank = true
          technique = nil
        end

        technique_params = {
          :technique_id => technique.id,
          :count => unit_count,
          :decoration_id => decoration && decoration.id,
        }
      end

      if (!@user and
          (item = @order.items.find(:first, :conditions => item_params)) and
          (!technique or item.decorations.find(:first, :conditions => technique_params)) and
          (oiv = item.order_item_variants.find(:first, :conditions => { :variant_id => variant && variant.id })))
        oiv.quantity = quantity
        oiv.save!
        
        # Reset price with new quantity
        #item.price = item.normal_price(blank) || PricePair.new(Money.new(0),Money.new(0))
        item.price = nil
        item.sample_requested = (params[:disposition] == 'sample')
        item.save!
      else
        # Create Order Item
        item = @order.items.new(item_params)
        item.save!

        item.order_item_variants.create(:variant => variant,
                                        :quantity => quantity)

        # Don't fix price until order revised
        #item.price = item.normal_price(blank) || PricePair.new(Money.new(0),Money.new(0))
        item.sample_requested = (params[:disposition] == 'sample')
        item.save!
        
        if technique
          decor = item.decorations.new(technique_params)
          normal = decor.normal_price
          decor.price = normal if normal and normal.is_a?(Money)
          decor.save!
        end
      end

      if blank
        item.task_complete({ :user_id => session[:user_id],
                             :host => request.remote_ip }, ArtExcludeItemTask)
      end
      
      # Don't change task if item added to existing order even if order acknowledged
      unless (@order.task_completed?(AcknowledgeOrderTask) or @order.task_completed?(PaymentNoneOrderTask)) and (params[:disposition] == 'exist') and @permissions.include?('Super')
        task_complete({ :data => { :product_id => product.id, :item_id => item.id }},
                      AddItemOrderTask, [AddItemOrderTask, RequestOrderTask, RevisedOrderTask, QuoteOrderTask])
      end
    end

    # Wait until all has succeeded to write session
    set_order_id(@order.id)

    if @user
      if params[:disposion] == 'customer'
        redirect_to :action => :contact, :order_id => @order
      else
        redirect_to :controller => "/admin/orders", :action => :items_edit, :order_id => @order
      end
    else
      redirect_to :action => :items, :order_id => @order, :task => 'AddItemOrder'
    end
  end
  
public
  def orders
    if params[:customer_id]
      @customer = Customer.find(params[:customer_id])
      @order = @customer.orders.find(:first, :order => 'id DESC')
    end
  end

  def_tasked_action :items, ItemNotesOrderTask, 'Art' do
    @address = @order.customer.ship_address ||= Address.new
    
    @static = @order.task_completed?(AcknowledgeOrderTask)
    
    @javascripts = ['quote.js', 'autosubmit.js']   
    
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
  
  def_tasked_action :item_remove, RemoveItemOrderTask do
    OrderItem.transaction do
      item = @order.items.find(params[:id])
      item.destroy
      task_complete({ :data => { :product_id => item.product.id, :item_id => item.id } },
                    RemoveItemOrderTask, [RemoveItemOrderTask])
    end
    redirect_to :back
  end
  
  def shipping_get
    item = @order.items.find(params[:id])
    customer = @order.customer
    
    address = (customer.ship_address ||= Address.new)
    if address.postalcode != params[:postalcode]
      Customer.transaction do
        address.postalcode = params[:postalcode]
        address.save!
        customer.ship_address = address
        unless customer.default_address_id and
                customer.default_address_id != customer.ship_address_id
          customer.default_address = address
        end
        customer.save(:validate => false)

        customer.shipping_rates_clear!
      end
    end

    @rates = item.shipping_rates(true)

    unless @rates
      render :inline => "Unable to calculate shipping information."
      return
    end
    
    render :partial => 'shipping', :locals => { :rates => @rates }
  end
  
  # Order Information
  def_tasked_action :info, InformationOrderTask do    
    @javascripts = ['quote.js', 'autosubmit.js']
#    apply_calendar_header

    @static = @order.task_completed?(AcknowledgeOrderTask) && (!@user || !params[:unlock])
    
    if request.post?
      params[:order]['delivery_date(1i)'] = Date.today.year.to_s if params[:order]['delivery_date(1i)'] and params[:order]['delivery_date(1i)'].empty?
      @order.update_attributes(params[:order])
      next unless @order.valid?
      Order.transaction do
        if (@order.changed? or !@order.task_completed?(InformationOrderTask))
          @order.save!
          task_complete({}, InformationOrderTask, [InformationOrderTask, RequestOrderTask, RevisedOrderTask], false)
        end
       end
      render_edit
    end
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
  
  # Customer Specific
public
  # Duplicated in orders controller
  %w(company_name person_name email phone).each do |method|
    define_method("auto_complete_for_customer_#{method}") do
      find_options = { 
        :conditions => [ "LOWER(#{method}) LIKE ? AND id != ?", '%' + params[:customer][method].downcase + '%', Integer(params[:customer_id]) ], 
        :order => "#{method} ASC",
        :limit => 10 }
      
      @items = Customer.find(:all, find_options)
      
      render :inline => "<%= auto_complete_result @items, '#{method}' %>"
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
        changed = @customer.changed? || @customer.phone_numbers.to_a.find { |p| p.changed? || p.marked_for_destruction? } || @customer.email_addresses.to_a.find { |p| p.changed? || p.marked_for_destruction? }

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
            @customer.ship_address.destroy
            @customer.ship_address = nil
            changed = true
          end
        end

        if @customer.valid?
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
        
        if @customer.valid?
          render_edit
          next
        end
      end
    end
    
    @javascripts = ['autosubmit.js', 'effects.js', 'controls.js']
    
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
    
    @javascripts = ['autosubmit.js'] #, 'upload_progress.js']
    @javascripts += ['effects.js', 'dragdrop.js'] if @user
    apply_calendar_header if @user

    task_complete({}, VisitArtworkOrderTask) unless @order.closed or @order.task_completed?(VisitArtworkOrderTask)
    
    next unless session[:user_id]
    
    determine_pending_tasks
    
    @permited = @order.permissions.find_all_by_name(self.class.artwork_tasks.collect { |t| t.roles }.flatten.uniq,
      :include => :user)
  end
  
  def artwork_add   
    if params[:artwork] and params[:artwork][:art] != ''
      Artwork.transaction do
        group_name = "Order #{@order.id}"

        unless @user
          group_name = "Customer Order #{@order.id}"
        else
          group = @order.customer.artwork_groups.to_a.find do |group|
            if group.order_item_decorations.empty?
              true
            else
              if group.order_item_decorations.to_a.find { |d| d.order_item.order_id != @order.id }
                false
              else
                @order.items.collect { |oi| oi.decorations }.flatten.length == 1
              end
            end
          end
        end
        group = @order.customer.artwork_groups.find_by_name(group_name) unless group
        group = @order.customer.artwork_groups.create(:name => group_name) unless group

        artwork = group.artworks.create(params[:artwork].merge(:user => @user, :host => request.remote_ip))
        if artwork.id
          artwork.tags.create(:name => 'customer') unless @user
          task_complete({ :data => { :id => artwork.id } }, ArtReceivedOrderTask, nil, false)
        end
      end
    end
        
#    redirect_to :action => :artwork, :task => 'ArtReceivedOrder'
    redirect_to :back
  end
  
  def artwork_edit
    Artwork.transaction do
      params[:artwork].each do |id, hash|
        artwork = Artwork.find(id)
        raise "Artwork row not found for customer_id: #{@order.customer_id} id: #{id}" unless artwork.group.customer_id == @order.customer_id
        artwork.update_attributes!(hash)
      end if params[:artwork]

      if @user
        { :decoration => OrderItemDecoration,
          :group => ArtworkGroup }.each do |name, klass|
          
          params[name] && params[name].each do |id, hash|
            item = klass.find(id)
            item.update_attributes!(hash)
          end
        end
      end
    end

    if /^((?:Send Art)|(?:Mark as Sent)) for (.+)$/ === params[:commit]
      Artwork.transaction do
        email_sent = $1.include?('Send')
        po = PurchaseOrder.find_by_quickbooks_ref($2)
        po.purchase.items.each do |item|
          item.task_complete({ :user_id => session[:user_id],
                               :host => request.env['REMOTE_HOST'],
                               :data => { :email_sent => email_sent }},
                             ArtSentItemTask)
        end
        SupplierSend.artwork_send(po.purchase, @user) if email_sent
      end
      redirect_to :back
      return
    end

    render_edit
  end
    
  def artwork_remove
    Artwork.transaction do
      art = Artwork.find(params[:id])
      raise "Art not associated with customer" unless art.group.customer_id == @order.customer_id
      art.tags.each { |t| t.destroy }
      art.destroy
    end
    redirect_to :action => :artwork, :order_id => @order
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
  
  def status
    Admin::OrdersController
    apply_calendar_header if session[:user_id]
#    @javascripts = ['calendar_date_select/calendar_date_select.js']
    
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
  end
  
  def_tasked_action :payment, PaymentInfoOrderTask, PaymentOverrideOrderTask, FirstPaymentOrderTask, FinalPaymentOrderTask do    
    @customer = @order.customer

    @javascripts = ['autosubmit.js']
    
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

  def payment_use
    PaymentInfoOrderTask.transaction do
      payment_method = PaymentMethod.find(params[:id], :include => :customer)
      raise "Payment not associated with customer" unless @order.customer_id == payment_method.customer_id
      raise "Already have payment info" unless payment_method.billing_id and !@order.task_completed?(PaymentInfoOrderTask)
      
      task_complete({ :data => { :id => payment_method.id } },
                    PaymentInfoOrderTask)
    end
    redirect_to :action => :payment, :order_id => @order
  end
  
  def payment_remove
    PaymentMethod.transaction do
      payment_method = PaymentMethod.find(params[:id], :include => :customer)
      raise "Payment not associated with customer" unless @order.customer_id == payment_method.customer_id

      payment_method.revoke!

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
    redirect_to :action => :payment, :order_id => @order
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
 
  def create_invoice
    @order.save_price!
    invoice = @order.generate_invoice
    invoice.comment = params[:invoice][:comment]
    invoice.save!
    redirect_to :action => :acknowledge_order
  end
  
  def_tasked_action :acknowledge_order, AcknowledgeOrderTask do
    @order_task = OrderTask.new(params[:order_task])

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
    render :pdf => 'invoice', :layout => 'print'
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

  def_tasked_action :review, ReviewOrderTask do
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
