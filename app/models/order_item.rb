OrderItemVariant

class OrderItem < ActiveRecord::Base
  belongs_to :order
  belongs_to :price_group
  belongs_to :product
  has_many :order_item_variants, :order => 'id'
  
  # Tasks  
  OrderTask
  include ObjectTaskMixin  
  has_tasks 
  def tasks_context
    @task_context ||= order.tasks_context + order.tasks_dep.find_all { |t| t.is_a?(OrderItemTask) && t.object == self }
  end

  has_many :decorations, :class_name => 'OrderItemDecoration', :foreign_key => 'order_item_id', :order => "order_item_decorations.id DESC"
  has_many :entries, :class_name => 'OrderItemEntry', :foreign_key => 'order_item_id', :order => "order_item_entries.id"
  belongs_to :purchase
  
  has_many :invoice_entries, :class_name => 'InvoiceOrderItem', :foreign_key => 'entry_id', :conditions => "type = 'InvoiceOrderItem'"


  def active_images
    variants = order_item_variants.collect { |oiv| oiv.quantity != 0 ? oiv.variant : nil }.compact
    if variants.empty? or (variants.include?(nil) and variants.length == 1)
      product.product_images.to_a
    else
      variants.compact.collect { |v| v.product_images.to_a }.flatten.uniq
    end
  end
  

  # Remove sometime?
  def properties_sub
    ret = {}
    product.property_groups.flatten.each do |prop|
      next if Property.is_image?(prop)
      ret[prop] = order_item_variants.collect do |oiv|
        next nil unless oiv.quantity != 0
        next 'Not Specified' unless oiv.variant
        pr = oiv.variant.properties.to_a.find { |p| p.name == prop }
        pr && pr.translate
      end.compact
    end
    ret
  end

  # Remove sometime?
  def description
    prop_str = properties_sub.collect { |name, list| "#{name}: #{list.join(', ')}" }
    "#{product.supplier_num} - #{product.name}  (#{prop_str})"
  end
  
  @@invoice_attributes = %w(price_group_id product_id marginal_price fixed_price shipping_type shipping_code shipping_price shipping_cost our_notes)
  def invoice_data
    ret = @@invoice_attributes.inject({}) { |h, a| h[a] = attributes[a]; h }
    ret['decorations'] = decorations.collect { |d| d.invoice_data }
    ret['entries'] = entries.collect { |e| e.invoice_data }
    ret['order_item_variants'] = order_item_variants.collect { |v| (v.quantity != 0) ? v.invoice_data : nil }.compact
    logger.info(ret.inspect)
    ret
  end
  
  def sub_items
    decorations + entries
  end
  
  # Cascade to change update_at up to order
  after_save :cascade_update
  after_destroy :cascade_update
  def cascade_update
    order.updated_at_will_change!
    order.save!
    if purchase
      purchase.updated_at_will_change!
      purchase.save! 
    end
  end

  after_create :qb_on_demand
  def qb_on_demand
    if product.quickbooks_id == 'BLOCKED'
      product.quickbooks_id = nil
      product.save!
    end
  end
  
  def quickbooks_ref
    product.quickbooks_id
  end
  
  def quantity
    order_item_variants.inject(0) { |sum, v| sum += v.quantity; sum }
  end
  
  # DB values
  %w(price cost).each do |type|
    composed_of type.to_sym, :class_name => 'PricePair', :mapping => [ ["marginal_#{type}", 'marginal'], ["fixed_#{type}", 'fixed'] ]
    composed_of "shipping_#{type}".to_sym, :class_name => 'Money', :mapping => ["shipping_#{type}", 'units'], :allow_nil => true
  end
 
  
  # Calculated price pair for price group given quantity
  def normal_price(blank = false)
    pricing = price_group.pricing(quantity)
    pair = if pricing.pair_at
      if pricing.pair_at.nil?
        # Above Maximum
        pricing.pair_at(pricing.breaks.last.minimum-1)
      else
        # Normal
        pricing.pair_at
      end
    else
      # Below Minimum
      if blank
        prices = PriceCollection.new(product)
        prices.adjust_to_profit!
        price = prices.price_range(prices.minimums.first).max
        PricePair.new(price, Money.new(0))
      else
        pricing.pair_at(pricing.breaks.first.minimum)
      end
    end
    pair.fixed = Money.new(0) if blank
    pair
  end
    
  def normal_cost
    price_group.price_entry_at([quantity, pricing.breaks.first.minimum].max)
  end

  # Shipping
  def normal_h
    { "OrderItem-#{id}-shipping_price" => shipping ? shipping.price.to_i : 0,
      "OrderItem-#{id}-shipping_cost" => shipping ? shipping.cost.to_i : 0}
  end
  
  def normal_all_h
    prefix = "#{self.class.name}-#{id}"
    ret = {}
    %w(price cost).each do |attr|
      val = send("normal_#{attr}")
      next unless val
      val.to_h.each do |prop, value|
        ret["#{prefix}-#{attr}-#{prop}"] = value
      end
    end
    decorations.each do |decoration|
      next if decoration.technique_id == 1  # don't do blank ???
      ret.merge!(decoration.normal_h)
    end
    ret.merge!(normal_h)
    ret
  end
  
  # List price/cost is the db set value or expected value if db isn't set
  %w(price cost).each do |type|
    define_method "list_#{type}" do
      normal = send("normal_#{type}")
      return send(type) unless normal
      normal.merge(send(type))
    end

    define_method "list_shipping_#{type}" do
      return send("shipping_#{type}") if send("shipping_#{type}")
      s = shipping
      return s.send(type) if s
      Money.new(0)
    end

    define_method "save_#{type}!" do
      decorations.each { |d| d.send("save_#{type}!") }
      send("#{type}=", send("list_#{type}"))
      send("shipping_#{type}=", send("list_shipping_#{type}"))
      save!
    end
  end
  
  def pricing
    price_group.pricing(quantity)
  end
  
  %w(price cost).each do |type|
    define_method "total_#{type}" do
      list = send("list_#{type}")
      unit = MyRange.new list.marginal
      total = MyRange.new list.fixed
      (decorations+entries).each do |d|
        list = d.send("list_#{type}")
        next nil unless p = list.marginal || Money.new(0)
        unit += p
        total += list.fixed || Money.new(0)
      end

      # Shipping
      p = send("list_shipping_#{type}")
      total += p if p
      
      res = total + unit * quantity
      res.single || res
    end
  end

  ShippingRate
  def shipping_rates(fetch = false)
    @shipping_rates ||= ShippingRate.rates(quantity, product, order.customer, fetch)
  end
  
  def shipping_find(type, code)
    shipping_rates && shipping_rates.find { |r| r.type == type and r.code == code }
  end
  
  def shipping
    shipping_find(shipping_type, shipping_code)
  end

  def shipping=(ship)
    update_attributes(:shipping_type => ship.type,
                      :shipping_code => ship.code)
  end

  def shipping_description(exclude_transit = false)
    shipping && shipping.description(exclude_transit)
  end

  def shipping_id
    "#{shipping_type}-#{shipping_code}"
  end
  
  before_destroy :destroy_children
  def destroy_children
    decorations.each { |d| d.destroy }
    entries.each { |e| e.destroy }
    order_item_variants.each { |v| v.destroy }
    (tasks_active + tasks_inactive).each { |t|  t.destroy }
  end
end
