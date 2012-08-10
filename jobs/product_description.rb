class PropertyError < StandardError
  def initialize(msg, property = nil)
    @msg, @property = msg, property
  end
  attr_reader :msg, :property

  def to_s
    "#{msg} for #{property}"
  end
end

module PropertyObject
  def self.included(base)
    base.instance_eval do
      include InstanceMethods
      extend ClassMethods
    end
  end

  module InstanceMethods
    def merge(hash)
      unknown = (hash.keys - self.class.properties.keys )
      PropertyError.new("unknown key: #{unkown.inspect}") unless unkown.empty?
      hash.each do |key, value|
        send("#{key}=", value)
      end
    end

    def initialize(hash = nil)
      merge(hash) if hash
    end
  end

  module ClassMethods
    def properties
      @properties ||= {}
    end

    def test_type(name, type, value, tail = '')
      if Array === type
        raise PropertyError.new("expected #{type}" + tail, name) unless Array === value
        value.each do |e|
          raise PropertyError.new("expected #{type} in Array" + tail, name) unless value.is_a?(type.first)
        end
        raise PropertyError.new("expected unique Array" + tail, name) unless value.uniq.length == value.length
      else
        raise PropertyError.new("expected #{type}" + tail, name) unless value.is_a?(type)
      end
    end

    def property(name, type, options = {}, &block)
      properties[name] = options[:nil]
      define_method("#{name}=") do |value|
        if block
          self.class.test_type(name, type, value) unless options[:no_pre]
          begin
            value = block.call(value)
          rescue PropertyError => e
            raise PropertyError.new(e.msg, name)
          end
          self.class.test_type(name, type, value, ' from property method')
        else
          self.class.test_type(name, type, value)
        end
        instance_variable_set("@#{name}", value)
      end

      define_method(name) do
        raise PropertyError.new("didn't expect block", name) if block and !options[:block]
        if block_given?
          i = type.new
          yield i
        else
          i = instance_variable_get("@#{name}")
        end
        return i if i || options[:nil]
        instance_variable_set("@#{name}", type.new)
      end
    end
  end
end


class ImageNodeFetch; end
class SupplierPricing; end

class DecorationDesc
  include PropertyObject

  property :technique, String ## !!!! Add validation here
  property :location, String
  property :limit, Integer

  [:width, :height, :diameter].each do |name|
    property name, Float, :nil => true
  end
end

class LeadTimeDesc
  include PropertyObject
  
  property :normal_min, Integer
  property :normal_max, Integer
  property :rush, Integer, :nil => true
end

class PackageDesc
  include PropertyObject
  
  [:length, :width, :height].each do |name|
    property name, Float
  end
  
  property :weight, Float
  property :units, Integer
end

class VariantDesc
  include Comparable
  def <=>(right)
    supplier_num <=> right.supplier_num
  end

  include PropertyObject

  property :supplier_num, String do |s| s.strip end
  property :properties, Hash
  property :images, Array[ImageNodeFetch]

  property :pricing, SupplierPricing, :block => true

  def merge(hash)
    hash.each do |key, value|
      case key
      when 'prices'
        pricing.prices = value
      when 'costs'
        pricing.costs = value
      else
        send("#{key}=", value)
      end
    end
  end
end

class ProductDesc
  include PropertyObject

  property :supplier_num, String do |s| s.strip end

  property :name, String do |s| s.strip end

  property :description, Array, :no_pre => true do |v|
    if Array === v
      v.each { |e| raise PropertyError, "expected Array of String" unless String === e }
    elsif String === v
      v.split("\n")
    else
      raise PropertyError, "expected String or Array of String"
    end
  end

  property :tags, Array[String]  # !!! PROVIDE WARNING WHEN TAG IS CREATED

  property :supplier_categories, Array do |v|
    raise PropertyError, "expected non empty Array" if v.empty?
    v.each do |e|
      raise PropertyError, "expected Array of Array" unless Array === e
      riase PropertyError, "expected Array of non empty Array" if e.empty?
      e.each do |s|
        raise PropertyError, "expected Array of Array of String" unless String === s
      end
    end
    v
  end

  property :images, Array[ImageNodeFetch]

  property :decorations, Array[DecorationDesc]

  property :variants, Array[VariantDesc] do |v|
    raise PropertyError.new("expected at least 1") if v.empty?
  end

  property :properties, Hash # Properties applied to all variants

  property :lead_time, LeadTimeDesc

  property :package, PackageDesc

  property :data, Hash

  def validate
    # check all variants have the same set of properties
    prop_list = variants.collect { |v| v.properties.keys }.flatten.compact.uniq.sort
    variants.each do |variant|
      next if properties.keys.sort == prop_list
      prop_list.each do |prop_name|
        unless properties[prop_name]
          raise ValidateError.new("Variant property mismatch", "Variant \"#{variant['supplier_num']}\" doesn't have property \"#{prop_name}\" unlike [#{(product_data['variants'].collect { |v| v['supplier_num'] } - [variant['supplier_num']]).join(', ')}]")
        end
      end
    end

    # Check uniq variant properties
    properties = variants.collect { |v| v.properties }
    unless properties.uniq.length == properties.length
      raise ValidateError.new("Variant properties not unique", properties.inspect)
    end  

    # check images
    variant_images = variants.collect { |v| v.images }.flatten
    raise ValidateError, "No images" if (variant_images + images).empty?
    images.each do |pi|
      if variant_images.find { |vi| vi == pi }
        raise ValidateError.new("Duplicate image", "#{pi.inspect} of #{variant_images.inspect}")
      end
    end

  end

  def merge(hash)
    hash.each do |key, value|
      case key
      when 'lead_time_normal_min'
        lead_time.normal_min = value
      when 'lead_time_normal_max'
        lead_time.normal_max = value
      when 'lead_time_rush'
        lead_time.rush = value
      when /^package_(\w+)$/
        package.send("#{$1}=", value)
      when 'decorations'
        decorations = value.collect { |d| DecorationDesc.new(d) }
      when 'variants'
        variants = value.collect { |d| VariantDesc.new(d) }
      else
        send("#{key}=", value)
      end
    end
  end

  def initialize(hash = nil)
    if hash
      
    end
  end
end
