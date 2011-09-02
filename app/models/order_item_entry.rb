class OrderItemEntry < ActiveRecord::Base
  belongs_to :order_item
  
  # Cascade to change update_at up to order
  after_save :cascade_update
  after_destroy :cascade_update
  def cascade_update
    order_item.touch
  end
  
  %w(price cost).each do |type|
    composed_of type.to_sym, :class_name => 'PricePair', :mapping => [ ["marginal_#{type}", 'marginal'], ["fixed_#{type}", 'fixed'] ]
    
    alias_method "list_#{type}", type
  end
  
  def list_description
    description || ''
  end
  
  def quickbooks_ref
    nil
  end
  
  @@invoice_attributes = %w(description marginal_price fixed_price)
  def invoice_data
    @@invoice_attributes.inject({}) { |h, a| h[a] = attributes[a]; h }
  end
end
