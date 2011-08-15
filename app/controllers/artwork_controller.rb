class ArtworkController < OrdersController
  def create
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
  
  def edit
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
    
  def destroy
    Artwork.transaction do
      art = Artwork.find(params[:id])
      raise "Art not associated with customer" unless art.group.customer_id == @order.customer_id
      art.tags.each { |t| t.destroy }
      art.destroy
    end
    redirect_to :back
  end
end
