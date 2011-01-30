class Variant < ActiveRecord::Base
  belongs_to :product
  has_and_belongs_to_many :properties, :after_remove => :destroy_after_remove   
  has_and_belongs_to_many :price_groups, :after_remove => :destroy_after_remove
#  has_and_belongs_to_many :product_images
  
  has_many :order_item_variants
  
  def price_group_order_items_count
    OrderItem.count(:include => { :price_group => :variants },
                    :conditions => "variants.id = #{id}")
  end

  def destroy_after_remove(obj)
    obj.destroy if obj.variants.empty?
  end

  def set_images(images)
    orig = product_images.to_a.dup
    images.delete_if do |img|
      pi = orig.find { |pi| pi.supplier_ref == img.id }
      orig.delete(pi) if pi
    end

    images.each do |img|
      product_images.create(:supplier_ref => img.id,
                            :image => img.get,
                            :product => product)
    end

    orig.each do |pi|
      pi.destroy
    end
  end
    
  def set_property(name, value, str)
#   Load all properties
    prop = properties.to_a.find { |prop| prop.name == name }
    orig = nil
    if prop
      orig = prop.value
      return prop if prop.value == value
      properties.delete(prop)
    end
    if value
      prop = Property.get(name, value)
      properties << prop
    end
    str << "   #{name}: #{orig.inspect} => #{value.inspect}\n" if orig != value
    prop
  end
  
  def find_supplier_price
    source_id = product.supplier.price_source.id
    price_groups.find_by_source_id(source_id)
  end

  # Used by OrderItemVariant#description
  def properties_unique
    product.property_groups.flatten.inject({}) do |hash, prop|
      unless Property.is_image?(prop)
        pr = properties.to_a.find { |p| p.name == prop }
        hash[prop] = pr && pr.translate if pr
      end
      hash
    end
  end
end
