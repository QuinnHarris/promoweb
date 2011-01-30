class Purchase < ActiveRecord::Base
  has_many :items, :class_name => 'OrderItem', :foreign_key => 'purchase_id', :order => "order_items.id"
  has_many :entries, :class_name => 'PurchaseEntry', :foreign_key => 'purchase_id'
  belongs_to :supplier

  has_one :purchase_order
  has_one :bill

  def fax?
    supplier.po_email.nil? || supplier.po_email.empty?
  end
  
  def order
    items.first.order
  end
  
  alias_method :supplier_orig, :supplier
  def supplier
    supplier_orig || items.first.product.supplier
  end

  def artwork_groups
    items.to_a.collect { |i| i.decorations.to_a.collect { |d| d.artwork_group } }.flatten.compact
  end

  def artwork_has_tag?(tag)
    not artwork_groups.find { |g| not g.artworks.to_a.find { |a| a.has_tag?(tag) } }
  end
  
  after_save :cascade_update
  def cascade_update
    if purchase_order
      unless purchase_order.sent
        purchase_order.updated_at_will_change!
        purchase_order.save!
      end

      if bill
        bill.updated_at_will_change!
        bill.save!
      end
    end
  end
end
