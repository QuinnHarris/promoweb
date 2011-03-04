class PurchaseEntry < ActiveRecord::Base
  belongs_to :purchase
  has_many :invoice_entries, :class_name => 'InvoicePurchaseEntry', :foreign_key => 'entry_id', :conditions => "type = 'InvoicePurchaseEntry'"
  
  %w(price cost).each do |name|
    composed_of name.to_sym, :class_name => 'Money', :mapping => [name, 'units'], :allow_nil => true
    alias_method "list_#{name}", name
    define_method "total_#{name}" do
      (send(name) || Money.new(0)) * quantity
    end
  end
  
  def invoice_description
    description
  end
  
  def sub_items; []; end

  # Cascade to change update_at up to order
  after_save :cascade_update
  after_destroy :cascade_update
  def cascade_update
    purchase.updated_at_will_change!
    purchase.save!

    purchase.order.updated_at_will_change!
    purchase.order.save!
  end
end
