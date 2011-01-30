class OrderItemDecoration < ActiveRecord::Base
  belongs_to :order_item
  belongs_to :technique, :class_name => 'DecorationTechnique', :foreign_key => 'technique_id'
  belongs_to :decoration
  belongs_to :artwork_group
  
  # Cascade to change update_at up to order
  after_save :cascade_update
  after_destroy :cascade_update
  def cascade_update
    order_item.updated_at_will_change!
    order_item.save!
  end
  
  %w(price cost).each do |type|
    composed_of type.to_sym, :class_name => 'PricePair', :mapping => [ ["marginal_#{type}", 'marginal'], ["fixed_#{type}", 'fixed'] ]
  end
  
  # Dimention proxy
  @@dim_reg = /(\d+\.\d{1,3})x(\d+\.\d{1,3})/
  def has_dimension?
    return true if decoration_id
    @@dim_reg === our_notes
  end

  def width
    return decoration.width if decoration_id
    @@dim_reg === our_notes
    Float($1)
  end

  def height
    return decoration.height if decoration_id
    @@dim_reg === our_notes
    Float($2)
  end

  # Make Act like order_item_entry
  def description
    name = (technique.name == 'General') ? '' : technique.name
    "#{name} #{attributes['description']}".strip
  end
  
  def quickbooks_ref
    technique.quickbooks_id
  end
  
  def list_count
    count
  end
  
  def pricing
    return @pricing if @pricing
    product = order_item.product
    return nil unless dec_price_group = product.supplier.find_decoration_price_group(technique)
    limit = decoration ? decoration.limit : nil
    limit = technique.decorations.find_all_by_product_id(product.id).collect { |d| d.limit }.compact.max unless limit
    @pricing = dec_price_group.pricing(count, limit, order_item.quantity)
  end
  
  %w(price cost).each do |type|
    define_method "normal_#{type}" do
      return PricePair.new(0,0) unless pricing
      pricing.send(type)
    end
    
    define_method "list_#{type}" do
      send("normal_#{type}").merge(send(type))
    end

    define_method "save_#{type}!" do
      send("#{type}=", send("list_#{type}"))
      save!
    end
  end
  
  def normal_h
    prefix = "#{self.class.name}-#{id}"
    ret = {}
    %w(price cost).each do |attr|
      send("normal_#{attr}").to_h.each do |prop, value|
        ret["#{prefix}-#{attr}-#{prop}"] = value
      end
    end
    ret
  end
  
  @@invoice_attributes = %w(technique_id decoration_id description count marginal_price fixed_price)
  def invoice_data
    @@invoice_attributes.inject({}) { |h, a| h[a] = attributes[a]; h }
  end
end
