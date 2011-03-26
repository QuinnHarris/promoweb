class Purchase < ActiveRecord::Base
  has_many :items, :class_name => 'OrderItem', :foreign_key => 'purchase_id', :order => "order_items.id"
  has_many :entries, :class_name => 'PurchaseEntry', :foreign_key => 'purchase_id'
  belongs_to :supplier

  has_one :purchase_order
  has_one :bill

  def fax?
    supplier.fax?
  end

  def send_email
    supplier.send_email(order.sample)
  end

  def reconciled
    return @reconciled unless @reconciled.nil?
    @reconciled = items.first.task_completed?(ReconciledItemTask)
  end

  def locked(unlock = false)
    reconciled || (!unlock && purchase_order && purchase_order.sent)
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

  def ship_by_date
    return Date.today.add_workday(1) if order.sample
    return nil unless lt = max_lead_time
    Date.today.add_workday(lt)
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

  def supplier_status_url
    case supplier.name
      when "Gemline"
      # Improve!
      "http://www.gemline.com/MyGemline/"
      when "Leeds"
      # Improve!
      "http://my2.leedsworld.com/"
      when "Lanco"
      "http://www.lancopromo.com/orderstatus?refonetype=CSTPONBR&refone=#{purchase_order.quickbooks_ref}&reftwotype=custnmbr&reftwo=#{supplier.account_number}"
      #when "Prime Line"
      #""
      when "High Caliber Line"
      "http://icheck.highcaliberline.com/partqtypopup/PartQtyPopup.aspx?Action=OrderStatus&CustNbr=#{supplier.account_number}&ASI=&SO=&PO=#{purchase_order.quickbooks_ref}"
      when "Bullet Line"
      "http://www.bulletline.com/distributorservices/MyBulletLine.aspx?view=quickorder&pono=#{purchase_order.quickbooks_ref}&cusno=#{supplier.account_number}"
    end
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
