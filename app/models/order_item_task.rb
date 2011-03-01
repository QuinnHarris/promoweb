class OrderItemTask < ActiveRecord::Base
  belongs_to :object, :class_name => 'OrderItem', :foreign_key => 'order_item_id'
  belongs_to :user
  serialize :data
  
  include TaskMixin
end

# Dummy class for status page item header
class HeaderItemTask
#  include TaskMixin
  def initialize(item_task)
    @item_task = item_task
  end
  
  def new_record?; true; end
  def active; false; end
  def ready?; false; end
  def admin; false; end
    
  def cols
    @item_task.cols
  end
  
  def item
    @item_task.object
  end
  
  def rows; 1; end
end

class ArtExcludeItemTask < OrderItemTask
  # Don't suggest this task
  self.status_name = 'Artwork Excluded'
  self.completed_name = 'Artwork Excluded'
  self.action_name = 'mark as <strong>no artwork required</strong> for this item'
  self.roles = %w(Orders)
  
  def self.blocked(object)
    super ||
      (!object.decorations.empty? && "item has a decoration") ||
      (object.order.task_completed?(ArtAcknowledgeOrderTask) && "artwork acknowledged")
  end
  
  def admin
    !new_record? and active
  end
end

class OrderSentItemTask < OrderItemTask
  set_depends_on [FirstPaymentOrderTask, PaymentOverrideOrderTask, PaymentNoneOrderTask], [ArtAcknowledgeOrderTask, ArtExcludeItemTask, ReOrderTask]
  self.status_name = 'Purchase Order to Supplier'
  self.waiting_name = 'Send Order to Supplier'
  self.completed_name = 'Order Sent to Supplier'
  self.roles = %w(Orders)
  
  def status
    false
  end
  
  def admin
    true
  end

  def email_complete

  end
  
  def execute_duration
    15.minutes
  end
end

class ArtSentItemTask < OrderItemTask
  set_depends_on [FirstPaymentOrderTask, PaymentOverrideOrderTask, PaymentNoneOrderTask], ArtAcknowledgeOrderTask
  self.status_name = 'Artwork to Supplier'
  self.waiting_name = 'Send Artwork to Supplier'
  self.completed_name = 'Artwork Sent to Supplier'
  self.action_name = 'Send artwork to supplier'
  self.roles = %w(Orders)

  # email_complete performed by outside code in supplier_send
  def email_complete; end
  
  def self.blocked(item)
    ret = super
    return ret if ret

    if item.decorations.collect { |d| d.artwork_group }.flatten.compact.collect { |g| g.artworks }.flatten.collect { |a| a.tags }.flatten.include?('supplier')
      return "An image must be marked as a Supplier before it can be sent to the supplier!"
    end

    nil
  end

#  def admin
#    true
#  end

  def execute_duration
    15.minutes
  end
end

class ConfirmItemTask < OrderItemTask
  set_depends_on OrderSentItemTask, [ArtSentItemTask, ArtExcludeItemTask, ReOrderTask]
  self.status_name = 'Order Confirmed by Supplier'
  self.waiting_name = 'Waiting for Order Confirmation from Supplier'
  self.completed_name = 'Order Confirmation Received from Supplier'
  self.uri = { :controller => '/order', :action => 'status' }
  self.roles = %w(Orders)
  
  def apply(params)
    unless object.purchase.bill
      bill = Bill.create(:purchase => object.purchase)
      self[:data] = { :bill => bill.id }
    end
  end
    
  def status
    false
  end
  
  def admin
    true
  end

  def execute_duration
    4.hours
  end
end

class EstimatedItemTask < OrderItemTask
  set_depends_on ConfirmItemTask
  self.status_name = 'Estimated Ship Date'
  self.waiting_name = 'Waiting for Estimated Ship Date'
  self.completed_name = 'Estimated Ship Date Recieved'
  self.uri = { :controller => '/order', :action => 'status' }
  self.roles = %w(Orders)
  
  def apply(params)
    self[:data] = { :ship_date => Date.parse(params[:data][:ship_date]),
      :ship_days => Integer(params[:data][:ship_days]),
      :ship_saturday => params[:data][:ship_saturday] == "1"}
  end
  
  def ship_date
    return nil unless data
    data[:ship_date].to_time + 17.hours
  end
  
  def ship_days
    return data[:ship_days] if data

    (object.shipping && object.shipping.days) || 5
  end
  
  def ship_saturday
    return nil unless data
    data[:ship_saturday]
  end

  def email_complete
    subject = "Estimated Ship Date: #{ship_date.strftime("%A %b %d, %Y")}"
    header = %(Hi #{object.order.customer.person_name}
Your order is currently in production and has an estimated ship date of #{ship_date.strftime("%A %b %d, %Y")}
Once you order ships I will be forwarding a tracking number for your order.
Please let me know if you have any questions.)
    CustomerSend.dual_send(self, subject, header)
  end

  def status
    true
  end

  def execute_duration
    1.day
  end
end

class ShipItemTask < OrderItemTask
  set_depends_on EstimatedItemTask
  self.status_name = 'Product Shipped'
  self.waiting_name = 'Waiting for Shipping Information'
  self.completed_name = 'Product Shipped'
  self.uri = { :controller => '/order', :action => 'status' }
  self.roles = %w(Orders)
  
  def apply(params)
  end
  
  def carrier
    return nil unless data
    data[:carrier]
  end
  
  def tracking
    return nil unless data
    data[:tracking]
  end
  
  def tracking_url
    case carrier
      when 'UPS'
       "http://wwwapps.ups.com/WebTracking/processInputRequest?loc=en_US&tracknum=#{tracking}"
      when 'FedEx'
       "http://www.fedex.com/Tracking?tracknumbers=#{tracking}"
    end
  end

  def email_complete
    subject = "Order Shipped with Tracking Number"
    header = %(Hi #{object.order.customer.person_name}
Your order has shipped.
Please find your tracking number for #{carrier} below.
<a href="#{tracking_url}">#{tracking}</a>
Please let me know when this arrives.)
    CustomerSend.dual_send(self, subject, header)
  end
  
  def status
    true
  end

  def execute_duration
    1.day
  end
  
  def complete_estimate
    unless depends_on.nil? or depends_on.first.new_record? or depends_on.first.ship_date.nil?
      # Complete by 9:00 am the next day
      #return time_add_workday(depends_on.first.ship_date, 1.day + 9.hours)
      return depends_on.first.ship_date + 4.hours
    end

    lead_time = object.order.rush ? object.product.lead_time_rush : object.product.lead_time_normal_max
    time_add_workday(depend_max_at, (lead_time || 15).days)
  end

  def delivery_estimate
    # Delivers by 5 pm
    time_add_workday(complete_estimate, depends_on.first.ship_days.days).beginning_of_day + 17.hours
  end
end

class ReconciledItemTask < OrderItemTask
  set_depends_on ShipItemTask
  self.status_name = 'Reconciled Invoice from Supplier'
  self.waiting_name = 'Waiting for Supplier Invoice'
  self.completed_name = 'Invoice Received from Supplier'
#  self.roles = %w(Orders)
  
#  def status; false; end
#  def admin; true; end
  def execute_duration
    2.days
  end
end

class ReceivedItemTask < OrderItemTask
  set_depends_on ShipItemTask
  self.status_name = 'Product Received by Customer'
  self.waiting_name = 'Waiting for Shipment to be Delivered'
  self.completed_name = 'Product Received'
  self.uri = { :controller => '/order', :action => 'status' }
  self.roles = %w(Orders)
  
  def apply(params)
  end
  
  def status
    true
  end

  def execute_duration
    1.day
  end
  
  def complete_estimate
    depends_on.first.delivery_estimate
  end
end

class AcceptedItemTask < OrderItemTask
  set_depends_on ReceivedItemTask
  self.status_name = 'Delivery Confirmed by Customer'
  self.waiting_name = 'Waiting for Customer to Confirm Delivery'
  self.completed_name = 'Customer Confirmed Delivery'
  self.action_name = 'Customer Confirmed Order Received'
  self.uri = { :controller => '/order', :action => 'status' }
  self.roles = %w(Orders)
  
  def apply(params)
  end
  
  def status
    true
  end

  def execute_duration
    2.days
  end
end
