# -*- coding: utf-8 -*-
class Admin::OrdersController < Admin::BaseController
  include ::OrdersController::OrderModule
  before_filter :setup_order, :except => [:set]
  
  OrderTask
  OrderItemVariant

  def show
    tasks_competed = [CustomerInformationTask]
    tasks_competed = TaskSet.set - [AddItemOrderTask] if params.has_key?(:all)

    order = Order.arel_table
    or_nodes = []
    or_nodes << order[:user_id].eq(session[:user_id]) if !permission?('Super') or params.has_key?(:mine)
    or_nodes << order[:user_id].eq(nil) if permission?('Orders')
    
    or_nodes << Arel::Nodes::SqlLiteral.new("orders.user_id IN (SELECT user_id FROM permissions WHERE user_id = #{session[:user_id]})") unless permission?('Super')
    or_node = or_nodes.inject(nil) { |a, b| a ? a.or(b) : b }

    os = Order.scoped.joins(:customer).where("customers.person_name != ''")
    os = os.where(:closed => false) unless params.has_key?(:closed)
    os = os.where(or_node) if or_node
    
    @count = os.count

    @orders = os.order('orders.id DESC').includes([{ :customer => [:tasks_active, :tasks_other, :phone_numbers, :email_addresses] }, :tasks_active, :tasks_other, :user, { :items => [{ :purchase => :purchase_order }, :tasks_active, :tasks_other, { :order_item_variants => { :variant => :product_images }}, { :product => :product_images }] }]).all

    urgent = @orders.find_all { |o| o.urgent_note && !o.urgent_note.strip.empty? }
    @groups = urgent.empty? ? [] : [ ['Urgent', urgent] ]

    today = Time.now.end_of_day
    ready_orders = @orders.collect do |order|
      time = order.tasks_allowed(@permissions).collect do |task|
        next unless task.complete_at and (task.complete_at < today)
        task.complete_at
      end.compact.min
      next unless time
      [order, time]
    end.compact.sort_by { |order, time| time }.collect { |order, time| order }
    @groups << ['Ready or Late', ready_orders] unless ready_orders.empty?


    if params[:sort] == 'task'
      groups = {}
      @orders.each do |o|
        klasses = o.tasks_allowed(@permissions).collect { |t| t.class }.uniq
        klasses.each { |n| groups[n] = (groups[n] || []) + [o] }
      end
      @groups += TaskSet.set.reverse.collect do |klass|
        next nil unless klass.waiting_name
        next nil unless groups.keys.include?(klass)
        [klass.waiting_name, groups[klass]]
      end.compact
    else
      @groups << [@groups.empty? ? nil : 'Normal', @orders - ready_orders - urgent]
    end

    @title = "Orders #{ready_orders.length} of #{@count}"
    @javascripts = ['rails.js']
  end
    
  def payment_apply
    # Validate format of amount
    amount = Money.new(Float(params[:transaction][:amount])).round_cents
    if amount.to_s != params[:transaction][:amount]
      render :inline => "Invalid entry #{params[:transaction][:amount].inspect} must be of form d+.dd as in 125.25."
      return
    end
    
    payment_method = PaymentMethod.find(params[:method_id], :include => :customer)
    throw "Payment Method doesn't match order" unless @order.customer_id == payment_method.customer_id

    # Must wrap required payment read in transaction
    PaymentTransaction.transaction do
      if params[:commit] == 'Charge'
        raise "Unexpected Charge" if payment_method.creditable?
        max = @order.total_billable
        raise "Expected positive billable for Charge" unless max.to_i > 0
        if @order.invoices.last.new_record?
          @order.save_price!
          @order.invoices.last.save!
        end
      elsif params[:commit] == 'Credit'
        if params[:txn_id]
          charge_transaction = PaymentTransaction.find(params[:txn_id])
          payment_method.credit_to(charge_transaction)
          max = charge_transaction.amount
        else
          charge_transaction = true
        end
        raise "Unexpected Credit" unless payment_method.creditable?
        max = -@order.total_billable
        raise "Expected negative billable for Credit" unless max.to_i > 0
      else
        raise "Unknown Action: #{params[:commit].inspect}"
      end

      max *= 1.1 if payment_method.is_a?(PaymentSendCheck)

      if amount > max
        render :inline => "Charge must be less than $#{max}"
        return
      end
    
      unless charge_transaction
        transaction = payment_method.charge(@order, amount, params[:transaction][:comment])

        logger.info("Trans: #{transaction.inspect}")
        
        unless transaction.is_a?(PaymentError) or @order.task_completed?(FirstPaymentOrderTask)
          task_complete({}, PaymentInfoOrderTask) unless @order.task_completed?(PaymentInfoOrderTask)
          task_complete({}, FirstPaymentOrderTask)
        end
      else
        payment_method.credit(@order, amount, params[:transaction][:comment], charge_transaction)
      end
    end
    
    redirect_to :controller => '/orders', :action => :payment
  end

  %w(company_name person_name).each do |field|
    auto_complete_for :customer, field
  end
  auto_complete_for :order, :id

  %w(phone_number email_address).each do |method|
    define_method("auto_complete_for_customer_#{method.pluralize}") do
      klass = method.camelize.constantize
      column = klass.main_column
      scope = method.camelize.constantize.scoped.where(["LOWER(#{column}) LIKE ?", '%' + params[:customer][method.pluralize].downcase + '%'])
      scope = scope.where(["customer_id != ?", params[:customer_id]]) if params[:customer_id]
        
      @items = scope.order("#{column} ASC").limit(10).all

      render :inline => "<%= auto_complete_result @items, '#{column}' %>"
    end
  end
  
  # Contact Search/Merge
  def contact_search
    field = params[:customer].keys.first
    value = params[:customer].values.first

    if %w(phone_numbers email_addresses).include?(field)
      column = field.singularize.camelize.constantize.main_column
      find_options = {
        :include => field,
        :conditions => ["#{field}.#{column} = ?", value]
      }
    else
      find_options = {
        :conditions => ["#{field} = ?", value] 
      }
    end
    
    customer = Customer.find(:first, find_options)
      
    if params[:order_id]
      redirect_to contact_order_path(@order, :customer_id => customer.id)
    else
      redirect_to orders_path(:customer_id => customer.id)
    end
  end
  
  # Fix artwork files
  def_tasked_action :contact_merge, CustomerMergeTask do
    Customer.transaction do
      discard_customer = Customer.find(params[:discard_customer_id])
      keep_customer = Customer.find(params[:keep_customer_id])
      raise "customers can't match" unless discard_customer.id != keep_customer.id
      unless discard_customer.id == @order.customer_id or
             keep_customer.id == @order.customer_id
        raise "One customer must match order"
      end

      %w(orders artwork_groups payment_methods).each do |assoc|
        discard_customer.send(assoc).each do |obj|
          obj.customer = keep_customer
          obj.save!
        end
      end

      used_addr = []
      unused_addr = []
      %w(default_address ship_address bill_address).each do |field|
        addr = discard_customer.send(field)
        if keep_customer.send(field)
          unused_addr << addr if addr
        else
          used_addr << addr
          keep_customer.send("#{field}=", addr)
        end
      end

      # Destroy customer record
      %w(tasks_active tasks_inactive shipping_rates).collect do
        |method| discard_customer.send(method) end.flatten.each { |o| o.destroy }
      discard_customer.destroy
      
      keep_customer.task_complete({ :user_id => session[:user_id],
                                :host => request.env['REMOTE_HOST'],
                                :data => discard_customer.attributes },
                              CustomerMergeTask, [CustomerMergeTask])

      discard_path = DATA_ROOT+"/customer/#{discard_customer.uuid}"
      if File.directory?(discard_path)
        FileUtils.mv(Dir.glob(discard_path + '/*'),
                     DATA_ROOT+"/customer/#{keep_customer.uuid}")
        FileUtils.rmdir(discard_path)
      end
    end
    redirect_to contact_order_path(@order)
  end

  def contact_find
    if params[:order] and !params[:order][:id].blank? and
        Order.exists?(params[:order][:id].to_i)
      redirect_to :controller => '/orders', :action => 'status_page', :id => params[:order][:id].to_i
      return
    end

    if params[:purchase_order] and !params[:purchase_order][:quickbooks_ref].blank?
      if po = PurchaseOrder.find_by_quickbooks_ref(params[:purchase_order][:quickbooks_ref])
        redirect_to :controller => '/admin/orders', :action => :items, :order_id => po.purchase.order.id
        return
      end
    end

    @customer = Customer.new
    @search = true
    @javascripts = ['effects.js', 'controls.js']
    render :template => '/orders/contact'
  end
    
  def task_execute
    User.transaction do
      params[:tasks].collect do |task_name|
        task_class = Kernel.const_get(task_name)
        raise "Permission Denied" if (task_class.roles & @permissions).empty?
        if params[:object_id]
          object = task_class.reflections[:object].klass.find(params[:object_id]) 
          raise "Object not found" unless object
        else
          raise "Not Order" unless task_class == task_class.reflections[:object].klass
          object = @order
        end

        unless @order.user_id
          @order.user = @user
          @order.save!
        end

        task_params = {
          :user_id => session[:user_id],
          :host => request.remote_ip,
          :data => (params[:data] || {}).symbolize_keys}
          
        if (params[:commit] && params[:commit].include?('Without Email')) || params[:without_email] || (params[:tasks].last != task_name)
          if task_class.instance_method_already_implemented?(:email_complete)
            task_params[:data].merge!(:email_sent => false)
          end
        end

        if params[:commit] && params[:commit].index('Save')
          object.task_save(task_params, task_class)
        else
          object.task_complete(task_params, task_class)
        end
      end if params[:tasks]

      if params[:delegate_perm]
        user = User.find(params[:user_id])
        user.permissions.create(:name => params[:delegate_perm], :order => @order)
        TaskNotify.deliver_delegate(@order, @user, user)
      end
    end

    redirect_to :back
#    if task = @order.task_next(@permissions) { |t| 
#        t.uri && ![AcknowledgeOrderTask, ArtAcknowledgeOrderTask].include?(t.class)}
#      redirect_to task.uri
#    else
#      redirect_to :controller => '/admin/orders', :action => :index
#    end
  end
  
  def task_revoke
    klass = Kernel.const_get(params[:class])
    raise "Permission Denied" unless klass.allowed?(@permissions)
    klass.transaction do
      task = klass.find(params[:task_id])
      task.active = nil
      task.save!
    end
    redirect_to :back
  end

  def task_comment
    OrderTask.transaction do
      task_class = Kernel.const_get(params[:class])
      raise "Permission Denied" if (task_class.roles & @permissions).empty?

      object = task_class.reflections[:object].klass.find(params[:object_id])

      time = case params[:commit]
             when /^(\d{2})m$/
               Time.now + Integer($1).minutes
             when /^(\d{1})h$/
               Time.now + Integer($1).hours
             when 'EOD'
               Time.now.beginning_of_day + 17.hours
             when /^(\d{1})d$/
               (Time.now.beginning_of_day + 17.hours).add_workday(Integer($1).days)
             else
               params[:task][:expected_at]
             end
      params[:task][:expected_at] = time

      attributes = {
        task_class.reflections[:object].primary_key_name => object.id,
        :active => false }
      task = task_class.find(:first, :conditions => attributes)
      task = task_class.new(attributes) unless task
      task.update_attributes(params[:task].merge(:user_id => session[:user_id]))
      task.save!
    end

    redirect_to :back
  end

  def restore
    Order.transaction do
      @order.closed = false
      @order.save!
      [CancelOrderTask, CompleteOrderTask].each do |klass|
        if task = klass.find(:first, :conditions => { 'order_id' => @order.id, 'active' => true })
          task.active = nil
          task.save!
        end
      end
    end

    redirect_to :back
  end

  def destroy
    return "Permission Denied" unless permission?('Super')
    fall = nil
    Order.transaction do
      fall = @order.customer.orders.find(:first, :conditions => "id != #{@order.id}", :order => 'id DESC')

      User.where(:current_order_id => @order.id).each do |user|
        user.update_attributes(:current_order_id => fall.id)
      end

      @order.destroy
    end
    session[:order_id] = fall.id
    redirect_to status_order_path(fall)
  end

  def invoice_create
    Invoice.transaction do
      @order.save_price!
      invoice = @order.generate_invoice
      invoice.comment = params[:invoice][:comment]
      invoice.save!
    end
    redirect_to :controller => '/orders', :action => :acknowledge_order
  end

  def invoice_destroy
    raise "Permission Denied" unless permission?('Super')
    Invoice.transaction do
      invoice = Invoice.find(params[:invoice_id])
      invoice.destroy
    end

    redirect_to :controller => '/orders', :action => :acknowledge_order
  end
  
  def permission_revoke
    User.transaction do
      perm = Permission.find(:first,
        :conditions => ["name = ? AND user_id = ? AND order_id = ?",
          params[:name], params[:user_id], params[:order_id]])
      perm.destroy
    end
    
    redirect_to :back
  end

  def create
    Customer.transaction do
      if params[:customer_id]
        @customer = Customer.find(params[:customer_id])
      else
        @customer = Customer.new({
            :company_name => '',
            :person_name => params[:name] || '' })
      end

      @customer.save(:validate => false)      
      @order = @customer.orders.create(:user_id => session[:user_id])
      session[:order_id] = @order.id
    end

    redirect_to contact_order_path(@order)
  end

  def create_email
    Customer.transaction do
      if customer = Customer.find(:first, :include => :email_addresses, :conditions => ['lower(email_addresses.address) ~ ?', params[:email].downcase]) and
          order = customer.orders.find(:first, :conditions => 'user_id IS NOT NULL', :order => 'id DESC')
        render :inline => "Customer already serviced by #{order.user.name}"
        return
      end

      customer = Customer.new({
                                 :company_name => '',
                                 :person_name => params[:name] || '' })

      customer.save(:validate => false)
      customer.email_addresses.create(:address => params[:email])
      
      @order = customer.orders.create(:user_id => session[:user_id])

      if /M(\d{4,5})/ === params[:subject] and
          product = Product.find($1) and
          (pg = PriceGroup.find(:all, :include => :variants, :conditions => { 'price_groups.source_id' => nil, 'variants.product_id' => product.id})).length == 1
        @order.items.create(:product_id => product.id,
                            :price_group_id => pg.first.id)
      end
      session[:order_id] = @order.id
    end

    redirect_to contact_order_path(@order)
  end

  def task_dependants(tasks)
    (tasks + tasks.collect { |t| task_dependants(t.depends_on.find_all { |u| !u.is_a?(AcknowledgeOrderTask) }) }).flatten
  end

  def duplicate
    Order.transaction do
      samples = params[:samples]
      free = params[:free] && samples

      if params[:spec]
        transfer_tasks = task_dependants([@order.tasks_dep.find { |t| t.is_a?(ArtAcknowledgeOrderTask) }]).find_all { |t| t.active? }
        task_complete({}, ReOrderTask)
      end

      # Create new order
      orig_order = @order
      @order = orig_order.customer.orders.create(:user => @user,
                                                 :special => params[:spec] ? 'SpecSample' : (samples ? "SAMPLES" : "Reorder"),
                                                 :delivery_date_not_important => samples || false)
      task_complete({}, InformationOrderTask)

      if params[:spec]
        transfer_tasks.each do |task|
          task.order_id = @order.id
          task.save!
        end
      end

      purchases = {}

      orig_order.items.each do |orig_item|
        # Price and Cost
        if samples
          pricing = orig_item.price_group.pricing
          price = free ? PricePair.new(0,0) : pricing.pair_at(pricing.maximum)
          cost = orig_item.price_group.price_entry_at(pricing.maximum)
        else
          price = orig_item.price
          cost = orig_item.cost
        end

        # Purchase if Exact ReOrder
        purchase = nil
        if params[:exact] || params[:spec]
          unless purchase = purchases[orig_item.purchase_id]
            purchase = purchases[orig_item.purchase_id] =
              Purchase.create(:order => @order,
                              :supplier_id => orig_item.purchase.supplier_id,
                              :comment => params[:exact] ? "Exact ReOrder of #{orig_item.purchase.purchase_order.quickbooks_ref}" : "Specification Sample")
            purchase.purchase_order = PurchaseOrder.create(:purchase => purchase)
            if params[:spec]
              p = orig_item.purchase
              p.comment = "Exact ReOrder of #{purchase.purchase_order.quickbooks_ref}" + (p.comment.blank? ? '' : " #{p.comment}")
              p.save!
            end
          end
        end

        item = @order.items.create( :product_id => orig_item.product_id,
                                    :price_group_id => orig_item.price_group_id,
                                    :price => price,
                                    :cost => cost,
                                    :purchase => purchase,
                                    :shipping_type => samples ? nil : orig_item.shipping_type,
                                    :shipping_code => samples ? nil : orig_item.shipping_code,
                                    :shipping_price => free ? Money.new(0) : nil )
        oivs = orig_item.order_item_variants.to_a
        if oiv_null = oivs.find { |v| v.variant_id.nil? }
          oivs.delete(oiv_null)
        else
          oiv_null = item.order_item_variants.new(:variant_id => nil,
                                                  :quantity => 0)
        end
        oivs.each do |oiv|
          if item.product.variants.to_a.find { |v| (v.id == oiv.variant_id) && (oiv.quantity > 0) } 
            item.order_item_variants.create(:variant_id => oiv.variant_id,
                                            :quantity => (samples || params[:spec]) ? 1 : oiv.quantity,
                                            :imprint_colors => samples ? '' : oiv.imprint_colors)
          else
            oiv_null.quantity += oiv.quantity
          end
        end
        oiv_null.save! if oiv_null.quantity > 0

        if samples
          item.entries.create(:description => 'Sample Item')
        else
          orig_item.decorations.each do |dec|
            dec_hash = {}
            [:technique_id, :decoration_id, :artwork_group_id, :count, :price, :cost, :description, :our_notes].each do |method|
              dec_hash[method] = dec.send(method)
            end
            if params[:exact]
              # No setup on Exact reorders
              dec_hash[:price].fixed = Money.new(0)
              dec_hash[:cost].fixed = Money.new(0)
            end
            item.decorations.create(dec_hash)
          end
          orig_item.entries.each do |entry|
            item.entries.create(:description => entry.description,
                                :price => entry.price,
                                :cost => entry.cost)
          end
        end

        task_complete({ :data => { :product_id => item.product.id, :item_id => item.id }.merge(samples ? {:sample => true} : {:reorder => true}) },
                      AddItemOrderTask, [AddItemOrderTask])

        item.task_complete({ :user_id => session[:user_id],
                             :host => request.remote_ip },
                           ArtExcludeItemTask) if samples
      end

      unless samples
        orig_order.entries.each do |entry|
          @order.entries.create(:description => entry.description,
                                :price => entry.price,
                                :cost => entry.cost)
        end
      end

      task_complete({}, PaymentNoneOrderTask) if free

      task_complete({}, ReOrderTask) if params[:exact]
    end

    redirect_to :action => :items, :id => @order.id
  end
  
  def own
    redirect_to :back

    if @order.user_id
      return if !params[:unown] and (@order.user_id == @user.id)
      raise "permission denied" unless params[:unown] or OwnershipOrderTask.allowed?(@permissions)
    end

    Order.transaction do
      task_complete({ :data => { :user_id => @order.user_id } }, OwnershipOrderTask, [OwnershipOrderTask])
      @order.user_id = params[:unown] ? nil : session[:user_id]
      @order.save!
    end
  end

  def order_item_variant_set
    OrderItem.transaction do
      oi = OrderItem.find(params[:id])
      if params[:variant_id]
        variant = oi.price_group.variants.find(params[:variant_id])
        raise "Variant not found" unless oi.variant = variant
      else
        oi.variant_id = nil
      end
      oi.save!
    end
    redirect_to :action => :items
  end

  def po
    @stylesheets = ['orders', 'admin_orders']
    @purchase = Purchase.find(params[:id])
    
    respond_to do |format|
      format.html
      format.pdf { render :pdf => 'po', :layout => 'print' }
    end
  end
  
  def purchase_create
    Purchase.transaction do
      supplier = Supplier.find(params[:supplier_id])
      item_ids = params[:item_po].collect { |id, val| id if val == '1' }.compact
      items = OrderItem.find(item_ids)
      items.each do |i| 
        raise "Item not from same supplier" unless i.product.supplier == supplier
        raise "Item not from same order" unless i.order_id == @order.id
      end

      # Set current user to own this order.  Needed for po.
      @order.user_id = session[:user_id] unless @order.user_id
      @order.save!

      unless supplier['name'] == params[:commit]
        supplier = Supplier.find(:first, :conditions => { :name => params[:commit], :parent_id => supplier.id })
        raise "Unkown Supplier name #{params[:commit]}" unless supplier
      end

      purchase = Purchase.create(:order => @order,
                                 :supplier => supplier)
      items.each do |item|
        item.purchase = purchase
        item.save_cost!
      end
      PurchaseOrder.create(:purchase => purchase)
    end
    redirect_to :action => :items
  end
  
  def purchase_mark
    Purchase.transaction do
      purchase = Purchase.find(params[:purchase_id])

      data = {}

      send_email = nil
      
      task_class = Kernel.const_get(params[:class])
      mark_art = nil
      case params[:class]
      when 'OrderSentItemTask'
        data[:email_sent] = false
        if params[:commit].include?("Send")
          SupplierSend.purchase_order_send(purchase, @user)
          data[:email_sent] = true
          mark_art = true if purchase.include_artwork_with_po?
        end
        purchase.purchase_order.sent = true
        purchase.purchase_order.save!
      when 'ConfirmItemTask', 'ReconciledItemTask', 'EstimatedItemTask', 'ShipItemTask', 'ReceivedItemTask', 'AcceptedItemTask'
        data = params[:data].symbolize_keys if params[:data]
        send_email = !params[:commit].include?('Without') if task_class.instance_method_already_implemented?(:email_complete)
      else
        raise "Unknown Action: #{task_class.inspect} #{params[:class]}"
      end

      raise "Permission Denied" if (task_class.roles & @permissions).empty?

      purchase.items.each do |item|
        par = { :user_id => session[:user_id],
          :host => request.env['REMOTE_HOST'],
          :data => { :po => purchase.id, :email_sent => send_email }.merge(data) }
        item.task_complete(par, task_class)
        send_email = nil
        item.task_complete(par, ArtSentItemTask) if mark_art
      end
    end
    redirect_to :action => :items
  end

protected
  def order_locks
    @unlock = params[:unlock] && permission?('Super')
    @price_lock = @order.task_completed?(AcknowledgeOrderTask) && !@unlock
  end
public
  
  def_tasked_action :items, RequestOrderTask, RevisedOrderTask, QuoteOrderTask, OrderSentItemTask, ReconciledItemTask do
    if params[:own]
      if @order.user
        render :inline => "Customer already serviced by #{@order.user.name}"
        next
      end
      @order.user = @user
      @order.save!
    end

    @stylesheets = ['orders', 'admin_orders']
    @javascripts = ['autosubmit.js', 'admin_orders', 'effects', 'controls', 'rails']
    apply_calendar_header
    
    # Populate supplier - po - item list
    @suppliers = {}
    @order.items.collect do |item|
      supplier = item.product.supplier
      purchase_list = @suppliers[supplier] || []
      purchase = item.purchase
      unless purchase
        if purchase_list.first and purchase_list.first.new_record?
          purchase = purchase_list.first
        else
          purchase = Purchase.new
        end
      end
      purchase.items << item if purchase.new_record?
      purchase_list << purchase unless purchase_list.index(purchase)
      @suppliers[supplier] = purchase_list
    end
    
    # Remove from here and fold into ReviesedOrderTask class
    unless @order.our_comments
      string =  "Hi #{@order.customer.person_name.split(' ').first},\n"
      string += "Thank you for contacting Mountain Xpress Promotions.\n"
      string += "Please review the revised quote below.\n"
      unless @order.task_completed?(PaymentInfoOrderTask)
        string += "You will be required to provide payment before the order can proceed and your artwork can be processed.\n"
      end
      string += "If everything is to your satisfaction, {click here to login and acknowledge the order}.\n"

      string += "Please let me know if I can answer any questions.\n"
      
      @order.our_comments = string
    end

    order_locks

    determine_pending_tasks

    render :layout => 'order'
  end
  
  @@set_classes = %w(Order OrderEntry OrderItem OrderItemDecoration OrderItemEntry OrderItemVariant Purchase PurchaseEntry Bill OrderItemVariantMeta)
  def get_klass(klass_name)
    raise "Unkown Class" unless @@set_classes.include?(klass_name)
    Kernel.const_get(klass_name)
  end

 def auto_complete_generic
    id_str, value = params.find { |k, v| /^\w+-\d+-description$/ === k }
    klass_name, id, attr, prop = id_str.split('-')

    find_options = { 
     :conditions => [ "LOWER(description) LIKE ? AND id != #{id}", value.downcase + '%' ], 
     :order => "id DESC",
     :limit => 10 }
    
    @items = get_klass(klass_name).find(:all, find_options)
    
    render :inline => "<%= auto_complete_result @items, 'description' %>"
  end
  
  def order_entry_insert
    order_locks
    klass = get_klass(params[:klass])
    order = klass.find(params[:id])
    entry = order.entries.create
    render :partial => 'order_entry', :locals => { :entry => entry, :purchase_lock => false }
  end
  
  def order_item_entry_insert
    order_locks
    order_item = OrderItem.find(params[:id])
    entry = order_item.entries.create
    render :partial => 'order_item_entry', :locals => { :entry => entry, :purchase_lock => order_item.purchase && order_item.purchase.locked(@unlock) }
  end
  
  def order_item_decoration_insert
    order_locks
    order_item = OrderItem.find(params[:id])
    entry = order_item.decorations.create({
      :technique_id => params[:technique]
    })
    render :partial => 'order_item_decoration', :locals => { :entry => entry, :purchase_lock => order_item.purchase && order_item.purchase.locked(@unlock) }
  end

  def order_item_remove
    klass = get_klass(params[:klass])
    entry = klass.find(params[:id])
    entry.destroy
    render :inline => ""
  end

  def shipping_get
    item = @order.items.find(params[:item_id])
    @script = true
    if item.shipping_rates(true)
      render :partial => 'order_item_shipping', :locals => { :item => item }
    else
      render :inline => 'Unable to Determing Shipping'
    end
  end

  def shipping_set
    klass_name, id, attr = params[:item_id].split('_')
    item = @order.items.find(id)
    type, code = params[:value].split('-')
   
    item.shipping_type = type
    item.shipping_code = code
    item.save!


    rate = item.shipping
    if rate
      render :inline => item.normal_h.to_json
    else
      logger.error("Unknwon Rate")
      render :inline => item.normal_h.to_json
    end
  end

  def variant_change
    Order.transaction do
      obj = set_common
      return unless obj
      obj.imprint_colors = params[:imprint]
      obj.save!
      
      quantity = obj.order_item.order_item_variants.collect do |oiv|
        next if oiv == obj
        oiv.destroy
        oiv.quantity
      end.compact.sum

      if quantity != Integer(params[:newValue])
        str = "Quantity mismatch: #{quantity} != #{Integer(params[:newValue])}"
        logger.error(str)
        render :inline => str
        return
      end
    end

    render :inline => "{}"
  end

  def set
    logger.info("SET")
    Order.transaction do
      obj = set_common
      return unless obj

      (obj.respond_to?(:to_destroy?) and obj.to_destroy?) ? obj.destroy : obj.save!
            
      if obj.respond_to?(:normal_h) and %w(quantity count).include?(@attr)
#      if (klass == OrderItemVariant and attr == "quantity") or
#         (klass == OrderItemDecoration and attr == "count")
        ret = obj.normal_h.to_json
        logger.info("Ret: #{ret.inspect}")
        render :inline => ret
      else
        render :inline => "{}"
      end
    end    
  end

  def set_common
    klass_name, id, @attr, prop = params[:id].split('-')
    klass = get_klass(klass_name)

    obj = klass.find(id)
    raise "Could find object" unless obj
    
    # dbValue
    dbValue = obj.send(@attr)
    dbValue = dbValue.send(prop) if prop
    
    # dbKlass
    if reflection = klass.reflections[@attr.to_sym]
      dbKlass = reflection.klass
    elsif column = obj.column_for_attribute(@attr)
      dbKlass = column.klass
    else
      raise "Unkown Class"
    end
    dbKlass = Money if dbKlass == PricePair and prop
    logger.info("dbKlass: #{dbKlass.inspect} #{dbValue.inspect}")
    
    # oldValue
    oldValue = params[:oldValue] == 'NaN' ? nil : dbKlass.new(params[:oldValue])
    
    # check old value
    if (dbValue != oldValue)
      str = "Value mismatch: #{oldValue.inspect} != #{dbValue.inspect}"
      logger.error(str)
      render :inline => str
      return false
    end
    
    # newValue
    if params[:newValue] == 'NaN'
      newValue = nil        
    else
      newValue = dbKlass.new(params[:newValue])
    end
    
    # set value
    if prop
      attr_obj = obj.send(@attr)
      attr_obj.send("#{prop}=", newValue)
      obj.send("#{@attr}=", attr_obj)
    else
      obj.send("#{@attr}=", newValue)
    end

    obj
  end
  
  
  def email
    require 'net/imap'
    imap = Net::IMAP.new("mountainofpromos.com")
    imap.login("web", "d8f32lDvc0desMre")
    imap.select("user.archive")

    addrs = @order.customer.email_addresses

    ids = imap.search(((1...addrs.length).collect { "OR" } + addrs.collect { |addr| ["OR", "FROM", addr.address, "TO", addr.address] }).flatten)
    @list = []
    @list = imap.fetch(ids, "(UID RFC822.SIZE BODY.PEEK[]<0.8192>)").reverse.collect do |msg|
      [msg.attr['RFC822.SIZE'], Mail.new(msg.attr['BODY[]<0>'])]      
    end unless ids.empty?

    @stylesheets = ['orders', 'admin_orders']

    render :layout => 'order'
  end

  def access
    @stylesheets = ['orders', 'access']

    @sessions = SessionAccess.find(:all, :include => [:pages, :orders],
                                   :conditions =>
                                   "user_id IS NULL AND session_accesses.id IN (SELECT session_access_id FROM access.order_session_accesses WHERE order_id = #{@order.id})")

    render :layout => 'order', :template => '/admin/access/paths'
  end
end
