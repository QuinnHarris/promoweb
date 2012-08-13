class PropertyError < ValidateError
  def initialize(value, property = nil)
    @value, @property = value, property
  end
  attr_reader :property

  def aspect
    "Property #{property}"
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
      unknown = hash.keys - self.class.properties.keys
      PropertyError.new("invalid key: #{unknown.inspect}") unless unknown.empty?
      hash.each do |key, value|
        send("#{key}=", value)
      end
    end

    def to_hash
      self.class.properties.keys.each_with_object({}) do |key, hash|
        hash[key] = send(key)
      end
    end

    def initialize(hash = nil)
      merge(hash) if hash
    end

    def [](key)
      return nil unless self.class.properties.keys.include?(key.to_s)
      send(key.to_s)
    end

    def ==(right)
      not self.class.properties.keys.find do |key|
        not send(key) == right.send(key)
      end
    end
    def !=(right)
      not self == right
    end
  end

  module ClassMethods
    def properties
      @properties ||= {}
    end

    def test_type(name, type, value, options, tail = '')
      if Array === type
        raise PropertyError.new("expected #{type} got #{value.inspect}" + tail, name) unless Array === value
        value.each do |e|
          raise PropertyError.new("expected #{type} in Array got #{e.inspect}" + tail, name) unless e.is_a?(type.first)
        end
        raise PropertyError.new("expected unique Array" + tail, name) unless value.uniq.length == value.length
      else
        raise PropertyError.new("expected #{type} got #{value.inspect}" + tail, name) unless value.is_a?(type) || (options[:nil] && value.nil?)
      end
    end

    def property(name, type, options = {}, &block)
      properties[name.to_s] = options[:nil]
      define_method("#{name}=") do |value|
        if block
          self.class.test_type(name, type, value, options) unless options[:no_pre]
          begin
            value = block.call(value)
          rescue PropertyError => e
            raise PropertyError.new(e.value, name)
          end
          self.class.test_type(name, type, value, options, ' after method')
        else
          self.class.test_type(name, type, value, options)
        end
        instance_variable_set("@#{name}", value)
      end

      define_method(name) do
#        if block_given?
#          raise PropertyError.new("didn't expect block", name) unless options[:block]
#          i = type.new
#          yield i
#        else
          i = instance_variable_get("@#{name}")
#        end
        return i if i || options[:nil]
        instance_variable_set("@#{name}", Array === type ? Array.new : type.new)
      end
    end
  end
end


class ImageNodeFetch; end
class SupplierPricing; end

class DecorationDesc
  include PropertyObject

  @@techniques = DecorationTechnique.all.each_with_object({}) { |i, h| h[i.name] = i }
  cattr_reader :techniques

  property :technique, String do |s|
    raise PropertyError, "got #{s} expected in #{@@techniques.keys.inspect}" unless @@techniques.keys.include?(s)
    s
  end
  def technique_record
    @@techniques[technique]
  end
  def to_hash
    super.merge('technique' => technique_record)
  end

  property :location, String
  property :limit, Integer, :nil => true

  [:width, :height, :diameter].each do |name|
    property name, Float, :nil => true
  end

  def ==(right)
    return false if (self.class.properties.keys - ['technique']).find do |prop|
      not send(prop) == right.send(prop)
    end
    right.is_a?(Decoration) ? technique_record.id == right.technique_id : technique == right.technique
  end
end

class LeadTimeDesc
  include PropertyObject
  
  property :normal_min, Integer
  property :normal_max, Integer
  property :rush, Integer, :nil => true
  # Rush Charge?
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
  # Cause uniq to consider only supplier_num
  def eql?(other); supplier_num.eql?(supplier_num); end
  def hash; supplier_num.hash; end

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

  @@tags = Tag.select(:name).uniq.collect { |t| t.name }
  property :tags, Array[String] do |array|
    array.each do |s|
      raise PropertyError, "got #{s} expected in #{@@tags.inspect}" unless @@tags.include?(s)
    end
    array
  end

  property :supplier_categories, Array do |v|
#    raise PropertyError, "expected non empty Array" if v.empty?
    v.each do |e|
      raise PropertyError, "expected Array of Array" unless Array === e
      riase PropertyError, "expected Array of non empty Array" if e.empty?
      e.each do |s|
        raise PropertyError, "expected Array of Array of String" unless String === s
      end
    end
    v
  end

  property :categories, Array, :nil => true

  property :images, Array[ImageNodeFetch]

  property :decorations, Array[DecorationDesc]

  property :variants, Array[VariantDesc] do |v|
    raise PropertyError.new("empty") if v.empty?
    v
  end

  property :properties, Hash # Properties applied to all variants

  property :lead_time, LeadTimeDesc

  property :package, PackageDesc

  property :data, Hash

  def validate
    # check presense
    self.class.properties.each do |key, value|
      next if value
      raise PropertyError.new("nil", key) if send(key).nil?
    end

    # check all variants have the same set of properties
    prop_list = variants.collect { |v| v.properties.keys }.flatten.compact.uniq.sort
    variants.each do |variant|
      next if variant.properties.keys.sort == prop_list
      prop_list.each do |prop_name|
        unless properties[prop_name]
          raise ValidateError.new("Variant property mismatch", "Variant \"#{supplier_num}\" doesn't have property \"#{prop_name}\" unlike [#{(variants.collect { |v| v.supplier_num } - [variant.supplier_num]).join(', ')}]")
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

  def validate_after
    all_images = ((variants.collect { |v| v.images }) + self.images).flatten.compact.uniq

    replace_images = {}

    dup_hash = {}
    dup_hash.default = []
    all_images.each do |image|
      unless size = image.size
        replace_images[image] = nil
        puts "  No Image: #{image.uri}\n"
        next
      end
      
      if (ref = dup_hash[size]) and
          match = ref.find { |r| FileUtils.compare_file(r.path, image.path) }
        replace_images[image] = match
        puts "  Duplicate Image: #{supplier_num} #{size} #{ref.inspect} #{image.inspect}\n"
      else
        dup_hash[size] += [image]
      end
    end

    raise ValidateError, 'No images after fetch' if (all_images - replace_images.keys).empty?

    variant_images = variants.collect do |variant|
      variant.images = variant.images.collect { |i| replace_images.has_key?(i) ? replace_images[i] : i }.compact.uniq
    end.flatten

    self.images = self.images.collect { |i| replace_images.has_key?(i) ? replace_images[i] : i }.compact.uniq - variant_images
  end

  def merge(hash)
    hash.each do |key, value|
      case key
      when 'lead_time_normal_min'
        self.lead_time.normal_min = value
      when 'lead_time_normal_max'
        self.lead_time.normal_max = value
      when 'lead_time_rush'
        self.lead_time.rush = value
      when /^package_(\w+)$/
        self.package.send("#{$1}=", value)
      when 'decorations'
        self.decorations = value.collect { |d| DecorationDesc.new(d) }
      when 'variants'
        self.variants = value.collect { |d| VariantDesc.new(d) }
      else
        send("#{key}=", value)
      end
    end
  end

  def initialize(hash = nil)
    merge(hash) if hash
  end
end
