class OrderItemVariant < ActiveRecord::Base
  belongs_to :order_item
  belongs_to :variant

  # Used by OrdersController#set
  def normal_h
    order_item.normal_all_h
  end

  @@invoice_attributes = %w(quantity imprint_colors variant_id)
  def invoice_data
    @@invoice_attributes.inject({}) { |h, a| h[a] = attributes[a]; h }
  end

  def description
    supplier_num = variant ? variant.supplier_num : order_item.product.supplier_num
    "#{supplier_num} - #{order_item.product.name}"
  end

  def quickbooks_ref
    order_item.quickbooks_ref
  end

  # Cascade to change update_at up to order_item
  after_save :cascade_update
  after_destroy :cascade_update
  def cascade_update
    order_item.updated_at_will_change!
    order_item.save!
  end

  def to_destroy?
    quantity == 0 and imprint_colors.blank? and quickbooks_po_id.blank? and quickbooks_bill_id.blank?
  end
end

# Used as place holder for empty OrderItemVariants
class OrderItemVariantMeta
  def self.fetch(order_item)
    all_variants = order_item.price_group.variants.to_a
    our_variants = order_item.order_item_variants.to_a

    variants = our_variants + all_variants.collect do |variant|
      unless our_variants.find { |v| v.variant_id == (variant && variant.id) } 
        OrderItemVariantMeta.new(order_item, variant)
      end
    end.compact
    if all_variants.length > 1 and !our_variants.find { |v| v.variant_id.nil? }
      variants.unshift OrderItemVariantMeta.new(order_item, nil)
    end
    variants
  end

  def initialize(order_item, variant)
    @order_item, @variant = order_item, variant
  end

  attr_reader :order_item, :variant

  def id
    "#{order_item.id}_#{variant && variant.id}"
  end

  def self.find(id)
    order_item_id, variant_id = id.split('_')
    OrderItemVariant.new(:order_item_id => Integer(order_item_id),
                         :variant_id => variant_id && Integer(variant_id),
                         :quantity => 0)
  end

  def quantity; 0; end
  def imprint_colors; nil; end
  def self.reflections; {}; end
end
