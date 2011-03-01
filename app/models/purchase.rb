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
    return @order if @order
    @order = items.first.order
  end

  def order=(order)
    @order = order
  end
  
  alias_method :supplier_orig, :supplier
  def supplier
    supplier_orig || items.first.product.supplier
  end

  def max_lead_time
    items.collect { |i| order.rush ? i.product.lead_time_rush : i.product.lead_time_normal_max }.compact.max
  end

  def add_weekdays(date, n)
    date += n.days + (2*(n/5.floor)).days
    date += 1.days until (1..5).member?(date.wday)
    date
  end

  def ship_by_date
    return nil unless lt = max_lead_time
    add_weekdays(Date.today, lt+1)
  end

  def max_transit_time
    items.collect { |i| i.shipping && i.shipping.days }.compact.max || 5
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

    order.push_quickbooks!
  end
end
