require 'rghost'
class EPSInfo
  def initialize(file_name)
    @file_name = file_name
    find_declares
  end

  private
  def find_declares(count = 100)
    @declares = {}
    File.open(@file_name).each do |line|
      if /^%%(\w+):\s(.+)$/ === line
        @declares[$1] = $2
      end
      count -= 1
      return if count == 0
    end
  end

  def format_bounding(header)
    header.split(/\s+/).collect { |s| Float(s) }
  end

  public
  # llx lly urx ury
  def bounding_box
    format_bounding @declares["HiResBoundingBox"] ||  @declares["BoundingBox"]
  end

  def page_bounding_box
    format_bounding @declares["PageBoundingBox"] || @declares["HiResBoundingBox"] ||  @declares["BoundingBox"]
  end
end

class RGhost::Paper
  def size
    case @paper
      when Symbol:
        RGhost::Constants::Papers::STANDARD[@paper.to_s.downcase.to_sym]
      when Array:
        @paper
    end
  end
end

class RGhost::Document
  attr_reader :paper
end


class Admin::OrdersController < Admin::BaseController
  include ::OrderController::OrderModule
  before_filter :setup_order, :except => [:set]
  
  OrderTask
  OrderItemVariant

  def index
    tasks_competed = [CustomerInformationTask]
    tasks_competed = TaskSet.set - [AddItemOrderTask] if params.has_key?(:all)
    
    include = [{ :customer => :tasks_active }, :tasks_active, :user, { :items => [{ :purchase => :purchase_order }, :tasks_active, :product ] }]
    conditions = ["order_tasks.active AND " +
        (params.has_key?(:closed) ? '' : "NOT closed AND ") +
        (params.has_key?(:mine) ? "(orders.user_id = #{session[:user_id]} OR orders.user_id IS NULL) AND " : '') +
        (@permissions.include?('Super') ? '' : "(orders.id IN (SELECT order_id FROM permissions WHERE user_id = #{session[:user_id]}) OR orders.user_id = #{session[:user_id]} #{@permissions.include?('Orders') ? 'OR orders.user_id IS NULL' : ''}) AND ") +
        ("(customers.person_name != '' OR order_tasks.type IN (?))"),
          tasks_competed.collect { |t| t.to_s }]
    
    @count = Order.count(:include=>include, :conditions=>conditions)
    @orders = Order.paginate(:all,
      :order => 'orders.id DESC',
      :include => include,
      :conditions => conditions,
      :page => params[:page] || 1,
      :per_page => 30)
    
    # Prefetch each order
#    @orders.each do |o|   
#      o.tasks_dep
#    end

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
  end
    
  def payment_charge
    # Validate format of amount
    amount = Money.new(Float(params[:transaction][:amount]))
    if amount.to_s != params[:transaction][:amount]
      render :inline => "Invalid entry #{params[:transaction][:amount]} must be of form d+.dd as in 125.25."
      return
    end
    
    payment_method = PaymentMethod.find(params[:id], :include => :customer)
    throw "Payment Method doesn't match order" unless @order.customer_id == payment_method.customer_id

    # Must wrap required payment read in transaction
    PaymentTransaction.transaction do
      if params[:commit] == 'Charge'
        max = @order.total_billable
        if @order.invoices.last.new_record?
          @order.save_price!
          @order.invoices.last.save!
        end
      elsif params[:commit] == 'Credit'
        charge_transaction = PaymentTransaction.find(params[:txn_id])
        max = charge_transaction.amount
      else
        raise "Unknown Action: #{params[:commit].inspect}"
      end    

      if amount.cents < 500 or amount > max
        render :inline => "Charge must be between $5.00 $#{max}"
        return
      end
    
      unless charge_transaction
        transaction = payment_method.charge(@order, amount, params[:transaction][:comment])
        
        unless transaction.is_a?(PaymentError) or @order.task_completed?(FirstPaymentOrderTask)
          task_complete({}, PaymentInfoOrderTask) unless @order.task_completed?(PaymentInfoOrderTask)
          task_complete({}, FirstPaymentOrderTask)
        end
      else
        payment_method.credit(@order, amount, params[:transaction][:comment], charge_transaction)
      end
    end
    
    redirect_to :controller => '/order', :action => :payment
  end

  %w(company_name person_name email phone).each do |field|
    auto_complete_for :customer, field
  end
    auto_complete_for :order, :id
  
  # Contact Search/Merge
  def contact_search
    customer = Customer.find(:first,
      :conditions => ["#{params[:customer].keys.first} = ?", params[:customer].values.first])
      
    if params[:order_id]
      redirect_to :controller => '/order', :action => :contact, :order_id => @order.id, :customer_id => customer.id
    else
      @order = customer.orders.find(:first, :order => 'id DESC')
      redirect_to :controller => '/order', :action => :orders, :order_id => @order.id
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
    redirect_to :controller => '/order', :action => :contact, :order_id => @order.id
  end

  def contact_find
    if params[:order] and params[:order][:id] and !params[:order][:id].empty? and
        Order.exists?(params[:order][:id].to_i)
      redirect_to :controller => '/order', :action => 'status', :order_id => params[:order][:id].to_i
      return
    end

    @customer = Customer.new
    @search = true
    @javascripts = ['effects.js', 'controls.js']
    render :template => '/order/contact'
  end
    
  def task_execute
    User.transaction do
      params[:tasks].collect do |task_name|
        task_class = Kernel.const_get(task_name)
        raise "Permission Denied" if (task_class.roles & @permissions).empty?
        if params[:id]
          object = task_class.reflections[:object].klass.find(params[:id]) 
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
          
        if (params[:commit] && params[:commit].index('Without Email')) || params[:without_email] || (params[:tasks].last != task_name)
          if task_class.instance_methods.include?('email_complete')
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
    raise "Permission Denied" unless @permissions.include?('Super')
    klass = Kernel.const_get(params[:class])
    klass.transaction do
      task = klass.find(params[:id])
      task.active = nil
      task.save!
    end
    redirect_to :back
  end

  def task_comment
    OrderTask.transaction do
      task_class = Kernel.const_get(params[:class])
      raise "Permission Denied" if (task_class.roles & @permissions).empty?

      object = task_class.reflections[:object].klass.find(params[:id])

      time = case params[:commit]
             when /^(\d{2})m$/
               Time.now + Integer($1).minutes
             when /^(\d{1})h$/
               Time.now + Integer($1).hours
             when 'EOD'
               Time.now.beginning_of_day + 17.hours
             when /^(\d{1})d$/
               Time.now.beginning_of_day + 17.hours + Integer($1).days
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
      order = Order.find(params[:id])
      order.closed = false
      order.save!
      [CancelOrderTask, CompleteOrderTask].each do |klass|
        if task = klass.find(:first, :conditions => { 'order_id' => order.id, 'active' => true })
          task.active = nil
          task.save!
        end
      end
    end

    redirect_to :back
  end

  def invoice_remove
    raise "Permission Denied" unless @permissions.include?('Super')
    Invoice.transaction do
      invoice = Invoice.find(params[:id])
      invoice.destroy
    end

    redirect_to :controller => '/order', :action => :acknowledge_order, :order_id => params[:order_id]
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
    
  def artwork_mark
    Artwork.transaction do
      artwork = Artwork.find(params[:id])
      raise "Art doesn't belong to customer" if artwork.group.customer_id != @order.customer_id

      tag = artwork.tags.find_by_name(params[:tag])
      raise "Already marked" if (params[:state] != "true") == tag.nil?

      if tag
        tag.destroy
      else
        artwork.tags.create(:name => params[:tag])
      end
    end

    redirect_to :controller => '/order', :action => :artwork, :order_id => @order.id
  end

  def artwork_drop_set
    OrderItemDecoration.transaction do
      group = params['artwork-group'].empty? ? nil : ArtworkGroup.find(params['artwork-group'])
      if params[:decoration]
        object = OrderItemDecoration.find(params[:decoration])
        raise "Customer Mismatch" if group && group.customer_id != object.order_item.order.customer_id
        object.artwork_group = group
        object.save!
      elsif params[:artwork]
        object = Artwork.find(params[:artwork])
        raise "Can't change customer" unless object.group.customer_id == group.customer_id
        object.group = group
        object.save!
      end
    end
    render :inline => ''
  end
 
  def artwork_group_new
    ArtworkGroup.transaction do
      customer = Customer.find(params[:customer_id])
      raise "Inconsistent customer #{customer.id} != #{params[:customer_id]}" unless customer.id == params[:customer_id].to_i
      ArtworkGroup.create(:name => 'New', :customer => customer)
    end
    redirect_to :back
  end

  def artwork_group_remove
    ArtworkGroup.transaction do
      group = ArtworkGroup.find(params[:id])
      raise "Inconsistent customer" unless group.customer_id == @order.customer_id
      raise "Not empty" unless group.artworks.empty? and group.order_item_decorations.empty?
      group.destroy
    end
    redirect_to :back
  end

  def artwork_generate_proof
    artwork = Artwork.find(params[:id])
    raise "Wrong file type or unassociated decoration" unless artwork.can_proof?(@order)

    # Setup variables for order
    company_name = artwork.customer.company_name.strip.empty? ? artwork.customer.person_name : artwork.customer.company_name

    imprint_file = artwork.art.path

    oid = artwork.group.order_item_decorations.first
    imprint_width = oid.width * 72
    imprint_height = oid.height * 72

    product_name = oid.order_item.product.name
    product_image = oid.order_item.product.image_path_absolute('main', 'jpg')

    props = {}
    imprint = []
    names = oid.order_item.product.property_group_names
    oid.order_item.order_item_variants.each do |oiv|
      next if oiv.quantity == 0

      names.each do |name|
        val = oiv.variant && (p = oiv.variant.properties.to_a.find { |p| p.name == name })
        props[name] = (props[name] || []) + [val ? val.value : 'Not Specified']
      end
      imprint << oiv.imprint_colors
    end

    # EPS info
    ei = EPSInfo.new(imprint_file)
    lx, ly, rx, ry = ei.page_bounding_box
    eps_width = (rx + lx)
    eps_height = (ry + ly)

    availible_space = 0

    paper = :letter
    landscape = (imprint_width > 7.5*72)
    logger.info("Landscape: #{landscape.inspect}")

    # Setup Document
    RGhost::Config::GS[:unit] = RGhost::Units::PSUnit
    doc = RGhost::Document.new :paper => paper, :landscape => landscape
    doc.info(:Title => 'Artwork Proof', :Author => @order.user && @order.user.name, :Subject => "#{product_name} on #{oid.decoration && oid.decoration.location}", :Producer => "Mountain Xpress Proof Creator using RGhost v#{RGhost::VERSION::STRING}")

    # Constants
    tick_offset = 6
    tick_length = 24

    paper_size = doc.paper.size
    paper_size = paper_size.reverse if landscape
    page_width, page_height = paper_size

    needed_space = 36 + 12 + (landscape ? 3*14 : 6*14) + tick_length*2 + 14*2 + 32
    availible_space = page_height - imprint_height

    page_margin = (availible_space - needed_space) / 2
    page_margin = 72/4 if page_margin < 72/4
    page_margin = 72 if page_margin > 72

    page_margin_left = 72*3/4

    center_x = page_width / 2

    # RGhost
    doc.define_tags do
      tag :title_font, :name => 'Helvetica-Bold', :size => 36
      tag :subtitle_font, :name => 'Times', :size => 12
      tag :bold_font, :name => 'Times-Bold', :size => 14
      tag :label_font, :name => 'Helvetica', :size => 10
    end

    # Title
    doc.moveto :x => center_x, :y => page_height - page_margin - 36
    doc.show "Artwork Proof", :with => :title_font, :align => :show_center

    pos_y = page_height - page_margin - 36 - 12
    info_list = ["Customer: #{company_name}",
     "Product: #{product_name}",
     oid.decoration && "Location: #{oid.decoration.location}",
     @order.user && "Rep: #{@order.user.name} (#{@order.user.email})"
    ].compact

    props.each do |key, list|
      info_list << "#{key.capitalize}: #{list.join(', ')}"
    end
    info_list << "Imprint: #{imprint.join(', ')}"

    pos_x = page_margin_left*2 + 72
    start_y = pos_y
    info_list.in_groups_of( (info_list.length / (landscape ? 2.0 : 1)).ceil ).each do |list|
      list.each do |name|
        pos_y -= 14
        doc.moveto :x => pos_x, :y => pos_y
        doc.show name, :with => :subtitle_font, :align => :show_left
      end
      pos_x += 72*3.75
      pos_y = start_y
    end

    center_y = (pos_y + page_margin + 48) / 2
    max_center_y = pos_y - imprint_height/2 - 64
    center_y = max_center_y if center_y > max_center_y
    
    # Product
    doc.image product_image, :zoom => 20, :x => page_margin_left*2, :y => page_height - page_margin - 36 - 36 - 36 - 8

    doc.moveto :x => center_x, :y => page_margin + 14
    doc.show "Mountain Xpress Promotions, LLC", :with => :bold_font, :align => :show_center

    doc.moveto :x => center_x, :y => page_margin
    doc.show "www.mountainofpromos.com  (877) 686-5646", :with => :subtitle_font, :align => :show_center

    # Crop marks
    doc.graphic do |g|
      g.line_width 0.5
      (0..3).each do |n|
        x_dir = (n&1 == 1) ? -1 : 1
        y_dir = (n&2 == 2) ? -1 : 1
        
        g.moveto :x => center_x + x_dir*imprint_width/2, :y => center_y + y_dir*(imprint_height/2 + tick_offset)
        g.rlineto :x => 0, :y => y_dir*tick_length
        
        g.moveto :x => center_x + x_dir*(imprint_width/2 + tick_offset), :y => center_y + y_dir*imprint_height/2
        g.rlineto :x => x_dir*tick_length, :y => 0
      end
      g.stroke
    end

    doc.graphic do |g|
      g.line_width 0.25
      g.border :color => :yellow
      g.moveto :x => center_x - imprint_width/2, :y => center_y - imprint_height/2
      g.rlineto :x => imprint_width, :y => 0
      g.rlineto :x => 0, :y => imprint_height
      g.rlineto :x => -imprint_width, :y => 0
      g.rlineto :x => 0, :y => -imprint_height
      g.stroke
    end

    # Crop mark Label
    doc.moveto :x => center_x, :y => center_y - imprint_height / 2 - tick_offset - tick_length
    doc.show "#{imprint_width / 72.0} in", :with => :label_font, :align => :show_center
    
    doc.moveto :x => center_x + imprint_width / 2 + tick_offset + tick_length / 2, :y => center_y - 4
    doc.show "#{imprint_height / 72.0} in", :with => :label_font
    
    # Scale
    offset_x = offset_y = 0
    scale_note = nil
    scale = [imprint_width/eps_width, imprint_height/eps_height].min
    if scale == imprint_width/eps_width
      offset_y = (imprint_height - eps_height*scale)/2
      scale_note = "width"
    else
      offset_x = (imprint_width - eps_width*scale)/2
      scale_note = "height"
    end

    unless scale == 1.0
      doc.moveto :x => center_x, :y => center_y - imprint_height / 2 - tick_offset - tick_length - 16
      doc.show "Scaled #{'%0.2f' % (scale * 100)}% (by #{scale_note})", :align => :show_center
      doc.scale(scale, scale)
    end

    # Insert eps
    doc.image imprint_file, :x => (center_x - imprint_width/2 + offset_x)/scale, :y => (center_y - imprint_height/2 + offset_y)/scale

    
    # Write File
    dst_name = artwork.filename_pdf
    dst_path = "/tmp/rghost-#{Process.pid}.pdf"

    doc.render :pdf, :filename => dst_path

    art_file = File.open(dst_path)
    eval "def art_file.original_filename; #{dst_name.inspect}; end"

    # Generate Artwork
    Artwork.transaction do
      proof_art = Artwork.find(:first, :include => :group, :conditions => ["artwork_groups.customer_id = ? AND artworks.art_file_name = ?", artwork.customer.id, dst_name])
      raise "File already exists" if proof_art

      proof_art = Artwork.create({ :group => artwork.group,
                                   :user => @user, :host => request.remote_ip,
                                   :customer_notes => "Proof generated from #{artwork.art.original_filename}",
                                   :art => art_file })
      proof_art.tags.create(:name => 'proof')

      unless artwork.tags.find_by_name('supplier')
        artwork.tags.create(:name => 'supplier')
      end
    end
   
    redirect_to :controller => '/order', :action => :artwork, :order_id => @order
  end

  def new_order
    Customer.transaction do
      if params[:customer_id]
        @customer = Customer.find(params[:customer_id])
      else
        @customer = Customer.new({
            :company_name => '',
            :person_name => '',
            :email => '',
            :phone => ''})
      end

      @customer.save_with_validation(false)
      
      @order = @customer.orders.create(:user_id => session[:user_id])
      
      session[:order_id] = @order.id
    end

    redirect_to :controller => '/order', :action => :contact, :order_id => @order
  end

  def order_duplicate
    Order.transaction do
      orig_order = @order.dup
      samples = params[:samples]
      free = params[:free] && samples

      # Create new order
      @order = orig_order.customer.orders.create(:user => @user,
                                                 :special => samples ? "SAMPLES" : "Reorder",
                                                 :delivery_date_not_important => samples || false)
      task_complete({}, InformationOrderTask)

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
        if params[:exact]
          unless purchase = purchases[orig_item.purchase_id]
            purchase = purchases[orig_item.purchase_id] =
              Purchase.create(:order => @order,
                              :supplier_id => orig_item.purchase.supplier_id,
                              :comment => "Exact ReOrder of #{orig_item.purchase.purchase_order.quickbooks_ref}")
            PurchaseOrder.create(:purchase => purchase)
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
          if item.product.variants.to_a.find { |v| v.id == oiv.variant_id } 
            item.order_item_variants.create(:variant_id => oiv.variant_id,
                                            :quantity => ((oiv.quantity == 0) or (!samples)) ? oiv.quantity : 1,
                                            :imprint_colors => oiv.imprint_colors)
          else
            oiv_null.quantity += oiv.quantity
          end
        end
        oiv_null.save! if oiv_null.quantity > 0

        if samples
          item.entries.create(:description => 'Sample Item')
        else
          orig_item.decorations.each do |dec|
            item.decorations.create([:technique_id, :decoration_id, :artwork_group_id, :count, :price, :cost].inject({}) do |hash, method|
                                      hash[method] = dec.send(method)
                                      hash
                                    end)
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
    redirect_to :action => :items_edit, :order_id => @order
  end
  
  def order_own
    Order.transaction do
      @order = Order.find(session[:order_id], :include => :user)
      raise "permission denied" if @order.user_id and !OwnershipOrderTask.allowed?(@permissions)
      task_complete({ :data => { :user_id => @order.user_id } }, OwnershipOrderTask, [OwnershipOrderTask])
      @order.user_id = params[:unown] ? nil : session[:user_id]
      @order.save!
    end
    redirect_to :back
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
    redirect_to :action => :items_edit
  end

  def po
    @stylesheets = ['order']
    @purchase = Purchase.find(params[:id])
    
    respond_to do |format|
      format.html
      format.pdf { render :pdf => 'po', :layout => 'print' }
    end
  end
  
  def purchase_create
    Purchase.transaction do
      supplier = Supplier.find(params[:id])
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
    redirect_to :action => :items_edit
  end
  
  def purchase_mark
    Purchase.transaction do
      purchase = Purchase.find(params[:id])

      data = {}

      if params[:commit].include?(OrderSentItemTask.status_name)
        data[:email_sent] = false
        if params[:commit].include?("Send")
          SupplierSend.purchase_order_send(purchase, @user)
          data[:email_sent] = true
        end
        purchase.purchase_order.sent = true
        purchase.purchase_order.save!
        task_class = OrderSentItemTask
      elsif ReconciledItemTask.status_name.include?(params[:commit])
        task_class = ReconciledItemTask
      else
        raise "Unknown Action: #{params[:commit].inspect}"
      end

      raise "Permission Denied" if (task_class.roles & @permissions).empty?

      purchase.items.each do |item|
        item.task_complete({ :user_id => session[:user_id],
                             :host => request.env['REMOTE_HOST'],
                             :data => { :po => purchase.id }.merge(data) }, task_class)
      end
    end
    redirect_to :action => :items_edit
  end

  def shipping_get
    item = @order.items.find(params[:id])
    @script = true
    if item.shipping_rates(true)
      render :partial => 'order_item_shipping', :locals => { :item => item }
    else
      render :inline => 'Unable to Determing Shipping'
    end
  end
  
  def_tasked_action :items_edit, RequestOrderTask, RevisedOrderTask, QuoteOrderTask, OrderSentItemTask, ReconciledItemTask do
    @stylesheets = ['order']
    @javascripts = ['autosubmit.js', 'admin_orders', 'effects', 'controls']
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
    
#    @locked = !params[:unlock]
    @invoiced = @order.task_completed?(AcknowledgeOrderTask)

    determine_pending_tasks
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
    klass = get_klass(params[:klass])
    order = klass.find(params[:id])
    entry = order.entries.create
    render :partial => 'order_entry', :locals => { :entry => entry, :poed => false }
  end
  
  def order_item_entry_insert
    order_item = OrderItem.find(params[:id])
    entry = order_item.entries.create
    render :partial => 'order_item_entry', :locals => { :entry => entry, :poed => false }
  end
  
  def order_item_decoration_insert
    order_item = OrderItem.find(params[:id])
    entry = order_item.decorations.create({
      :technique_id => params[:technique]
    })
    render :partial => 'order_item_decoration', :locals => { :entry => entry }
  end

  def order_item_remove
    klass = get_klass(params[:klass])
    entry = klass.find(params[:id])
    entry.destroy
    render :inline => ""
  end

  def shipping_set
    klass_name, id, attr = params[:id].split('_')
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

  def set
    klass_name, id, attr, prop = params[:id].split('-')
  
    klass = get_klass(klass_name)
    Order.transaction do
      obj = klass.find(id)
      raise "Could find object" unless obj

      # dbValue
      dbValue = obj.send(attr)
      dbValue = dbValue.send(prop) if prop
      
      # dbKlass
      if reflection = klass.reflections[attr.to_sym]
        dbKlass = reflection.klass
      elsif column = obj.column_for_attribute(attr)
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
        str = "DB: #{oldValue.inspect} != #{dbValue.inspect}"
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
        attr_obj = obj.send(attr)
        attr_obj.send("#{prop}=", newValue)
        obj.send("#{attr}=", attr_obj)
      else
        obj.send("#{attr}=", newValue)
      end
      
      (obj.respond_to?(:to_destroy?) and obj.to_destroy?) ? obj.destroy : obj.save!
#      obj.save!
      
      if obj.respond_to?(:normal_h) and %w(quantity count).include?(attr)
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
  
  
  def email_list    
    require 'net/imap'
    imap = Net::IMAP.new("mountainofpromos.com")
    imap.login("web", "d8f32lDvc0desMre")
    imap.select("user.archive")

    addrs = @order.customer.email.split(/\s*,\s*/)

    ids = imap.search(((1...addrs.length).collect { "OR" } + addrs.collect { |addr| ["OR", "FROM", addr, "TO", addr] }).flatten)
    @list = []
    @list = imap.fetch(ids, "(UID RFC822.SIZE BODY.PEEK[]<0.8192>)").reverse.collect do |msg|
      [msg.attr['RFC822.SIZE'], TMail::Mail.parse(msg.attr['BODY[]<0>'])]      
    end unless ids.empty?
  end

  def paths
    @stylesheets = ['access']

    @sessions = SessionAccess.find(:all, :include => [:pages, :orders],
                                   :conditions =>
                                   "user_id IS NULL AND id IN (SELECT session_access_id FROM order_session_accesses WHERE order_id = #{@order.id})")
  end
end
