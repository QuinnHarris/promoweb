# Includes TaskDefinition mixin
CustomerTask

class OrderTask < ActiveRecord::Base
  belongs_to :object, :class_name => 'Order', :foreign_key => 'order_id'
  belongs_to :user
  serialize :data
  
  include TaskMixin
  
  def email_delegate(user_id)
    
  end
end

class AddItemOrderTask < OrderTask
  self.status_name = 'Item(s) Added'
  self.waiting_name = 'Add Item'
  self.completed_name = 'Item Added'
  self.customer = true
  self.roles = %w(Customer Orders)
  
  def status
    dependants.first.new_record? # Disapear when Request is placed
    true
  end
end

class RemoveItemOrderTask < OrderTask
  self.completed_name = 'Item Removed'
  self.roles = %w(Customer Orders)
end

class ItemNotesOrderTask < OrderTask
  self.status_name = 'Item Notes'
  self.waiting_name = 'Provide Item Notes'
  self.completed_name = 'Item Notes Provided'
  self.roles = %w(Customer Orders)
end

class InformationOrderTask < OrderTask
  self.status_name = 'Order Info'
  self.waiting_name = 'Provide Order Information'
  self.completed_name = 'Order Information Provided'
  self.customer = true
  self.roles = %w(Customer Orders)
  
  def status
    dependants.first.new_record? # Disapear when Request is placed
    true
  end
end

# Placed after VisitArtworkOrderTask for proper "Next" sequence
class CustomerInformationTask < CustomerTask  
  self.status_name = 'Contact Info'
  self.waiting_name = 'Provide Contact Information'
  self.completed_name = 'Contact Information Provided'
  self.customer = true
  self.roles = %w(Customer Orders)
  
  def status
    dependants.first.new_record? # Disapear when Request is placed
    true
  end
end

class VisitArtworkOrderTask < OrderTask
  self.status_name = 'Artwork Page'
  self.waiting_name = 'Visit Artwork Page'
  self.completed_name = 'Artwork Page Visited'
  self.customer = true
  self.roles = %w(Customer Orders Art)
end

class RequestOrderTask < OrderTask
  set_depends_on AddItemOrderTask, InformationOrderTask, CustomerInformationTask
  self.status_name = 'Order Request'
  self.waiting_name = 'Request Order'
  self.completed_name = 'Order Requested'
  self.customer = true
  self.roles = %w(Customer Orders)
  self.action_name = 'Assume order request'
  self.auto_complete = true #[RevisedOrderTask, QuoteOrderTask]
  
  def email_complete
    if object.task_completed?(PaymentInfoOrderTask)
      subject = "Order Confirmation"
      header = 
%q(Thank you for placing an order with <a href='http://www.mountainofpromos.com/'>Mountain Xpress Promotions, LLC.</a>.
Please allow 24 hours to process your order.  We will contact you at the number or email provided for final price and artwork approval.
We look forward to working with you for your promotional needs.)
    else
      subject = "Quote Request Confirmation"
      header =
%q(Thank you for requesting a product quote from <a href='http://www.mountainofpromos.com/'>Mountain Xpress Promotions, LLC.</a>.
Please allow 24 hours to validate your quote. If we have any questions, we will contact you at the number provided.
We look forward to working with you for your promotional needs.)      
    end
    CustomerSend.dual_send(self, subject, header)
  end
  
  def status
    true
  end

  def execute_duration
    1.hour
  end
end

class QuoteOrderTask < OrderTask
  set_depends_on RequestOrderTask
  self.status_name = 'Order Quote'
  self.waiting_name = 'Quote Order'
  self.completed_name = 'Order Quoted'
  self.action_name = 'Quote Order'
  self.roles = %w(Orders)
    
  def email_complete
    subject = "Quote"
    header = data[:our_comment]
    CustomerSend.dual_send(self, subject, header)
  end
  
  def our_comment
    string = (data && data[:our_comment])
    return string if string

    string =  "Hi #{object.customer.person_name.split(' ').first},\n"
    string += "Thank you for contacting Mountain Xpress promotions.\n"
    string += "Please review the revised quote below.\n"
    string += "Please let me know if I can answer any questions.\n"
    string
  end
  
  def status
    active
  end

  def self.blocked(order)
    super || (order.task_completed?(RevisedOrderTask) && "Order Revised")
  end
  
  def execute_duration
    1.hour
  end
end

class RevisedOrderTask < OrderTask
  set_depends_on [RequestOrderTask, QuoteOrderTask]
  self.status_name = 'Order Revision'
  self.waiting_name = 'Revise Order'
  self.completed_name = 'Order Revised'
  self.action_name = 'Revise Order'
  self.roles = %w(Orders)
    
  def email_complete
    subject = if active
                "Order Reviewed, Ready for Acknowledgment" + 
                  (!object.task_completed?(PaymentInfoOrderTask) && " and Payment").to_s
    else
      "Order Rejected"
    end
    header = if active
               data[:our_comment]
             else
%q(This order has been rejected.  We will make the appropriate revisions and contact you.

Customer Comments:
) + data[:customer_comment] 
    end

    CustomerSend.dual_send(self, subject, header)
  end
  
  def our_comment
    string = (data && data[:our_comment])
    return string if string

    string =  "Hi #{object.customer.person_name.split(' ').first},\n"
    string += "Thank you for contacting Mountain Xpress promotions.\n"
    string += "Please review the revised order below.\n"
    unless object.task_completed?(PaymentInfoOrderTask)
      string += "You will be required to provide payment before the order can proceed and your artwork can be processed.\n"
    end
    string += "If everything is to your satisfaction, {click here to login and acknowledge the order}.\n"

    string += "Please let me know if I can answer any questions.\n"
    string
  end
  
  def status
    true
  end

  def self.blocked(order)
    ret = super
    return ret if ret

    problems = []
    
    address = order.customer.default_address
    unless address and (list = address.incomplete?).empty?
      problems << "Customer Address not complete: #{list.join(', ')}"
    end

    return "No in hands date" if order.delivery_date.nil?
    if order.delivery_date <= Date.today+2
      problems << "In hands date too soon: #{order.delivery_date.inspect}"
    end

    order.items.each do |item|
      item.order_item_variants.to_a.find do |oiv|
        if oiv.quantity > 0 and oiv.variant_id.nil?
          problems << "Quantity in Not Specified variant"
        end
      end
    end

    return problems.join(' and ') unless problems.empty?

    # CHECK SHIPPING !!!
    nil
  end

  def execute_duration
    1.hour
  end
end

class AcknowledgeOrderTask < OrderTask
  set_depends_on RevisedOrderTask
  self.status_name = 'Order Acknowledgment'
  self.waiting_name = 'Acknowledge Order'
  self.completed_name = 'Order Acknowledged'
  self.customer = true
  self.roles = %w(Customer Orders)
  
  def email_complete
    subject = "Order Acknowledged"
    header = %q(This order has been acknowledged.  The order items, decorations and quantities can not be changed.)
    CustomerSend.dual_send(self, subject, header)
  end
  
  def status
    true
  end

  def execute_duration
    1.day
  end
end

# Was "Before Request" why?
class PaymentInfoOrderTask < OrderTask
  self.status_name = 'Payment Information'
  self.waiting_name = 'Provide Payment Information'
  self.completed_name = 'Payment Information Provided'
  self.customer = true
  self.roles = %w(Customer Orders)
  self.notify = true
  
  def status
    true
  end
end

class PaymentOverrideOrderTask < OrderTask
  set_depends_on AcknowledgeOrderTask
  self.status_name = 'Payment Bypass'
#  self.waiting_name = 'Bypass Payment Information'
  self.completed_name = 'Payment Information Bypassed'
  self.action_name = 'ignore <strong>no customer payment and proceed with order</strong>'
  self.roles = %w(Super)

  def self.blocked(object)
    super || (object.task_completed?(PaymentInfoOrderTask) && "payment information received")
  end
end

class PaymentNoneOrderTask < OrderTask
  set_depends_on AddItemOrderTask, CustomerInformationTask
#  set_depends_on AcknowledgeOrderTask
  self.status_name = 'Payment not needed'
#  self.waiting_name = 'Mark as no Payment necissary'
  self.completed_name = 'Payment not neeeded'
  self.action_name = 'mark as <strong>no payment necassary</strong>'
  self.roles = %w(Super)

  def self.blocked(object)
    super || (object.task_completed?(PaymentInfoOrderTask) && "payment information received") ||
      (!object.total_item_price.zero? && "non zero invoice")
  end

  def admin
    !new_record? and active
  end
end


class FirstPaymentOrderTask < OrderTask
  set_depends_on AcknowledgeOrderTask, PaymentInfoOrderTask
  self.status_name = 'Customer Payment'
  self.waiting_name = 'Charge First Payment'
  self.completed_name = 'First Payment Charged'
  self.roles = %w(Orders)

  def status
    true
  end

  def execute_duration
    15.minutes
  end
end


class ArtDepartmentOrderTask < OrderTask; end;

class ArtReceivedOrderTask < OrderTask
  set_depends_on VisitArtworkOrderTask
  self.status_name = 'Artwork Upload'
  self.waiting_name = 'Customer Artwork'
  self.completed_name = 'Customer Artwork Received'
  self.action_name = 'accept existing artwork for this order'
  self.customer = true
  self.roles = %w(Customer Orders)
  self.auto_complete = true #[ArtDepartmentOrderTask]
  self.notify = true

  def self.blocked(object)
    super || (object.customer.artwork_groups.collect { |g| g.artworks }.flatten.empty? && "no existing artwork")
  end
  
  def status
    true
  end
end

class ArtOverrideOrderTask < OrderTask
  # Don't suggest this task
  self.status_name = 'Art Department Payment Override'
  self.completed_name = 'Sent to Art Department without Payment'
  self.action_name = 'ignore <strong>no customer payment and proceed with artwork</strong>'
  self.auto_complete = true #[ArtReceivedOrderTask, ArtDepartmentOrderTask]
  self.roles = %w(Super)
  
  def admin
    !new_record? and active
  end  
end

class ArtDepartmentOrderTask < OrderTask
  set_depends_on ArtReceivedOrderTask, [FirstPaymentOrderTask, ArtOverrideOrderTask]
  self.status_name = 'At Art Department'
  self.waiting_name = 'Send Artwork to Art Department'
  self.completed_name = 'Artwork sent to Art Department'
  self.action_name = 'mark art <strong>ready for preparation</strong>'
  self.roles = %w(Orders)
  
  def admin
    true
  end

  def execute_duration
    15.minutes
  end
end

class ArtPrepairedOrderTask < OrderTask
  set_depends_on ArtDepartmentOrderTask
  self.status_name = 'Artwork Preparation'
  self.waiting_name = 'Prepared Artwork'
  self.completed_name = 'Artwork Prepared'
  self.action_name = 'complete <strong>artwork preparation</strong> for customer'
  self.roles = %w(Orders Art)
  
  def self.blocked(order)
    super || 
    ((decorations = order.items.collect { |oi| oi.decorations }.flatten).find do |d|
      !d.artwork_group
    end && "All decorations must be associated with an artwork group") ||
    (decorations.find do |d|
      !d.artwork_group.artworks.to_a.find do |a|
        a.tags.find_by_name('proof')
      end
    end && "All used artwork groups must have an image marked as a Proof") ||
    (order.items.to_a.find do |i|
       next unless i.decorations.empty?
       !i.task_completed?(ArtExcludeItemTask)
     end && "All items without a decoration must be marked as no artwork required")
  end

  def email_complete
    if active
      subject = "Artwork ready for approval"
      header = our_comment
    else
      subject = "Artwork Rejected"
      header = %q(The artwork for this order has been rejected.  We will make the appropriate revisions and contact you.

Customer Comments:
) + data[:customer_comment]
    end
    CustomerSend.dual_send(self, subject, header)
  end
  
  def our_comment
    (data && data[:our_comment]) || "The artwork for your order is ready for review.  Please click on the Artwork Acknowledgment link above to view and acknowledge your artwork.  If you approve please acknowledge the artwork so we can go into production."
  end
  
  def status
    true
  end

  def execute_duration
    4.hours
  end
end

class ArtAcknowledgeOrderTask < OrderTask
  set_depends_on ArtPrepairedOrderTask
  self.status_name = 'Artwork Acknowledgment'
  self.waiting_name = 'Artwork Acknowledgment'
  self.completed_name = 'Artwork Acknowledged'
  self.customer = true
  self.roles = %w(Customer Orders)
  self.notify = %w(Art)
  
  def email_complete
    subject = "Artwork Acknowledged"
    header = %q(The artwork for this order has been acknowledged.  The artwork can no longer be changed.)
    CustomerSend.dual_send(self, subject, header)
  end
  
  def status
    true
  end

  def execute_duration
    1.day
  end
end


OrderItemTask

class CompleteOrderTask < OrderTask; end;

class FinalPaymentOrderTask < OrderTask
  set_depends_on FirstPaymentOrderTask, ShipItemTask, ReconciledItemTask
  self.status_name = 'Customer Payment'
  self.waiting_name = 'Charge Final Payment'
  self.completed_name = 'Final Payment Charged'
  self.action_name = 'mark final payment received'
  self.auto_complete = true #[CompleteOrderTask]
#  self.roles = %w(Orders)
  
  def self.blocked(order)
    super || (!order.total_billable.zero? && "Outstanding balance")
  end

  def execute_duration
    1.day
  end
end

class CompleteOrderTask < OrderTask
  set_depends_on ReceivedItemTask, [FinalPaymentOrderTask, PaymentNoneOrderTask], ReconciledItemTask
  self.status_name = 'Order Complete'
  self.waiting_name = 'Order Completion'
  self.completed_name = 'Order Complete'
  self.action_name = 'Order Complete'
  self.roles = %w(Orders)
  
  def apply(params)
    object.closed = true
    object.save!
  end

  def email_complete
    subject = "Order Complete"
    header = 
      %q(I would like to thank you for placing your order with Mountain Xpress Promotions. Please find below your attached invoices. Please print these for your records.
{I would also appreciate it if you would click on this link to review your experience with Mountainofpromos.com.}
Thank you for your business it is truly appreciated.
We look forward to working with you again!)

    CustomerSend.dual_send(self, subject, header)
  end
  
  def status
    true
  end

  def execute_duration
    1.day
  end  
end

class ReviewOrderTask < OrderTask
  set_depends_on ReceivedItemTask, [FinalPaymentOrderTask, PaymentNoneOrderTask]
  self.status_name = 'Customer Review'
  self.waiting_name = 'Customer Review'
  self.completed_name = 'Customer Review'
  self.roles = %w(Customer)

  @@aspect_names = ['Overall', 'Customer Service', 'Price', 'Product Selection', 'Website']
  @@aspect_methods = @@aspect_names.collect { |n| n.gsub(' ', '_') }
  @@option_methods = %w(show_company show_person show_products publish)
  cattr_reader :aspect_names, :aspect_methods, :option_methods

  (aspect_methods + option_methods).each do |name|
    define_method name do
      data && data[name]
    end
  end

  aspect_methods.each do |name|
    define_method "#{name}=" do |val|
      self[:data] ||= {}
      self[:data][name] = (val.to_i.to_s == val) ? val.to_i : nil
    end
  end

  option_methods.each do |name|
    define_method "#{name}=" do |val|
      self[:data] ||= {}
      self[:data][name] = (val == true || val == '1')
    end
  end

  def publish=(val)
    self[:data] ||= {}
    self[:data]['publish'] = case val
                             when true, 'true'
                               true
                             when false, 'false'
                               false
                             else
                               nil
                             end
  end

  def apply(params)
    comment.strip!
  end
end

class CancelOrderTask < OrderTask
  self.status_name = 'Order Canceled'
  self.action_name = 'Cancel Order'
  self.completed_name = 'Order Canceled'
#  self.roles = %w(Orders)

  def self.blocked(order)
    return super if super
    
    unless order.task_completed?(FinalPaymentOrderTask)
      return nil if order.total_charge.zero?
      if order.task_completed?(FirstPaymentOrderTask)
        return "first Payment made but not final payment"
      end
      return "order placed but no final payment" if order.items.to_a.find { |i| i.task_completed?(OrderSentItemTask) }
    end
    
    order.items.each do |item|
      return "Item in production but not received" if item.task_completed?(ConfirmItemTask) and !item.task_completed?(ReceivedItemTask)
    end
    
    nil
  end
  
  def apply(params)
    object.closed = true
    object.save!
  end
end

# Never Created in DB
class ClosedOrderTask < OrderTask
  set_depends_on [CompleteOrderTask, CancelOrderTask], AcceptedItemTask, ReviewOrderTask
end

class OwnershipOrderTask < OrderTask
  self.completed_name = 'Ownership Changed'
end
