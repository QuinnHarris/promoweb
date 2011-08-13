class OrderItemsController < OrdersController
  def add
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
        else
          technique_params = {
            :technique_id => technique.id,
            :count => unit_count,
            :decoration_id => decoration && decoration.id,
          }
        end
      end

      if (!@user and
          (item = @order.items.find(:first, :conditions => item_params)) and
          (!technique or item.decorations.find(:first, :conditions => technique_params)) and
          (oiv = item.order_item_variants.find(:first, :conditions => { :variant_id => variant && variant.id })))
        oiv.quantity = quantity
        oiv.save!
        
        # Reset price with new quantity
        #item.price = item.normal_price(blank) || PricePair.new(Money.new(0),Money.new(0))
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
        redirect_to :action => :contact
      else
        redirect_to items_admin_order_path(@order)
      end
    else
      redirect_to items_order_path(@order, :task => 'AddItemOrder')
    end
  end

  def_tasked_action :destroy, RemoveItemOrderTask do
    OrderItem.transaction do
      item = @order.items.find(params[:id])
      item.destroy
      task_complete({ :data => { :product_id => item.product.id, :item_id => item.id } },
                    RemoveItemOrderTask, [RemoveItemOrderTask])
    end
    redirect_to :back
  end

  # Defunct
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
end
