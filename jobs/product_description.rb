class PropertyError < ValidateError
  def initialize(value, prop = nil)
    @value= value
    @properties = []
    @properties << prop if prop
  end
  attr_reader :properties

  def append(prop)
    raise "Append must be string" unless prop.is_a?(String)
    @properties << prop
    self
  end

  def aspect
    "Property #{properties.reverse.join('.')}"
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
    def merge!(hash)
      unknown = hash.keys - self.class.properties
      PropertyError.new("invalid key: #{unknown.inspect}") unless unknown.empty?
      hash.each do |key, value|
        send("#{key}=", value)
      end
      self
    end

    def merge_from_object(object, hash)
      hash.each do |key, value|
        PropertyError.new("invalid key: #{key.inspect}") unless self.class.properties.include?(key)
        send("#{key}=", object[value])
      end
    end

    def to_hash
      self.class.properties.each_with_object({}) do |key, hash|
        hash[key] = send(key)
      end
    end

    def initialize(hash = nil)
      merge!(hash) if hash
    end

    def [](key)
      return nil unless self.class.properties.include?(key.to_s)
      send(key.to_s)
    end
    def []=(key, value)
      return nil unless self.class.properties.include?(key.to_s)
      send("#{key}=", value)
    end

    def ==(right)
      not self.class.properties.find do |key|
        not send(key) == right.send(key)
      end
    end
    def !=(right)
      not self == right
    end

    def validate_properties
      self.class.properties_hash.each do |key, (type, options)|
        value = instance_variable_get("@#{key}")
        raise PropertyError.new("nil", key) if !(options[:nil] || options[:warn] || options[:no_check]) && value.nil?
        next unless value
        begin
          value.validate if value.respond_to?(:validate)
          if type.is_a?(Array)
            value.each do |elem|
              elem.validate if elem.respond_to?(:validate)
            end
          end
        rescue PropertyError => e
          raise e.append(key)
        end
      end
    end
    def validate; validate_properties; end

    def warnings(import, context = nil)
      self.class.properties_hash.each do |key, (type, options)|
        value = instance_variable_get("@#{key}")
        if options[:warn]
          begin
            raise PropertyError.new("nil") if !(options[:nil] || options[:no_check]) && value.nil?
            value.validate if value.respond_to?(:validate)
          rescue PropertyError => e
            e.append(key)
            e.append(context) if context
            import.add_warning(e, supplier_num)
            instance_variable_set("@#{key}", nil)
          end
        end
        next unless value
        if type.is_a?(Array)
          value.each do |elem|
            begin
              elem.warnings(import, key) if elem.respond_to?(:warnings)
            rescue PropertyError => e
              import.add_warning(e.append(key), supplier_num)
            end
          end
        end
      end
    end
  end

  module ClassMethods
    def properties_hash
      @properties_hash ||= {}
    end
    def properties
      @properties_hash.keys
    end

    def test_type(name, type, value, options, tail = '')
      if Array === type
        raise PropertyError.new("expected #{type} got #{value.inspect}" + tail, name) unless value.is_a?(Array)
        value.each do |e|
          raise PropertyError.new("expected #{type} in Array got #{e.inspect}" + tail, name) unless e.is_a?(type.first)
        end
        raise PropertyError.new("expected unique Array" + tail + ": #{value.inspect}", name) unless value.uniq.length == value.length
      else
        raise PropertyError.new("expected #{type} got #{value.inspect}" + tail, name) unless value.is_a?(type) || (options[:nil] && value.nil?)
      end
    end

    def property(name, type, options = {}, &block)
      properties_hash[name.to_s] = [type, options]
      # Return nil if no new method but object is invalid if not set
      options[:nil] = true unless type.respond_to?(:new) || Array === type
      if [Integer, Float].include?(type) and !block
        options.merge!(:no_pre => true, :cast => true)
      end
      define_method("#{name}=") do |value|
        if block
          self.class.test_type(name, type, value, options) unless options[:no_pre]
          begin
            value = block.call(value)
          rescue PropertyError => e
            raise e.append(name.to_s)
          end
          self.class.test_type(name, type, value, options, ' after method')
        else
          if value and options[:cast]
            begin
              value = eval "#{type}(value)"
            rescue ArgumentError
              raise PropertyError.new("Invalide Argument: #{value}", name)
            end
          end
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

class DecorationDesc
  include PropertyObject

  @@techniques = DecorationTechnique.all.each_with_object({}) do |i, h|
    key = []
    p = i
    while p
      key << p.name
      p = p.parent
    end
    h[key.reverse] = i
  end
  cattr_reader :techniques

  property :technique, Array[String], :no_pre => true do |s|
    s = [s].flatten
    raise PropertyError, "got #{s} expected in #{@@techniques.keys.inspect}" unless @@techniques.keys.include?(s)
    s
  end   
  def technique_record
    @@techniques[technique]
  end
  def technique_id
    technique_record.id
  end
  def to_hash
    super.merge('technique' => technique_record)
  end

  property :location, String do |s| s.strip end
  property :limit, Integer, :nil => true

  [:width, :height, :diameter].each do |name|
    property name, Float, :nil => true
  end

  def ==(right)
    return false if (self.class.properties - ['technique']).find do |prop|
      not send(prop) == right.send(prop)
    end
    right.is_a?(Decoration) ? technique_record.id == right.technique_id : technique == right.technique
  end

  @@none = self.new(:technique => 'None', :location => '').freeze
  cattr_reader :none
end

class LeadTimeDesc
  include PropertyObject
  
  property :normal_min, Integer
  property :normal_max, Integer
  property :rush, Integer, :nil => true
  property :rush_charge, Float, :nil => true

  def validate
    validate_properties
    raise PropertyError, "must have rush if rush_charge" if rush_charge && !rush
  end
end

class PackageDesc
  include PropertyObject
  
  [:length, :width, :height].each do |name|
    property name, Float, :nil => true
  end
  
  property :weight, Float, :nil => true
  property :unit_weight, Float, :nil => true
  property :units, Integer

  def validate
    validate_properties
    raise PropertyError, "weight and unit_weight empty" unless weight || unit_weight
  end
end

class PricingDesc
  def initialize(prices = [], costs = [])
    @prices = prices
    @costs = costs
  end
  # Temp?
  attr_accessor :prices, :costs

  def validate
    raise ValidateError, "price empty" if prices.empty?
    raise ValidateError, "costs empty" if costs.empty?
  end

  def ==(right)
    prices == right.prices && costs == right.costs
  end

  def self.get
    sp = new
    yield sp
    sp.to_hash
  end

  # Duplicated in GenericImport Remove from there eventually
  def convert_pricecode(comp)
    return comp if comp.is_a?(Float) && comp > 0.0 && comp < 0.9
    return nil unless comp.is_a?(String) && /^[A-GP-X]$/i === comp
    comp = comp.upcase[0]
    num = comp.ord - ?A.ord if comp.ord >= ?A.ord and comp.ord <= ?G.ord
    num = comp.ord - ?P.ord if comp.ord >= ?P.ord and comp.ord <= ?X.ord
        
    0.5 - (0.05 * num)
  end
  
  def parse_qty(qty)
    return qty if qty.is_a?(Integer)
    Integer(qty.to_s.gsub(/(,(?=\d{3}(,|.|$)))|(\.0+$)/, ''))
  end

  def parse_money(val)
    return val if val.is_a?(Money)
    return Money.new(val) if val.is_a?(Float)
    Money.new(Float(val.gsub(/^\$/, '')))
  end

  def add(qty, price, code = nil)
    qty = parse_qty(qty)
    raise PropertyError, "qty must be positive" unless qty > 0
    raise ValidateError.new("minimums must be sequential", "#{@prices.last && @prices.last[:minimum]} >= #{qty}") if @prices.last && @prices.last[:minimum] >= qty

    price = parse_money(price)
    raise ValidateError.new("marginal price must be sequential", "#{@prices.last && @prices.last[:marginal]} < #{price} of #{@prices.inspect}") if @prices.last && @prices.last[:marginal] < price

    base = { :fixed => Money.new(0), :minimum => qty }
    @prices << base.merge(:marginal => price)

    if code
      discount = convert_pricecode(code)
      if discount
        price *= 1.0 - discount
      else
        price = parse_money(code)
      end
      
      raise ValidateError.new("marginal cost must be sequential", "#{@costs.last && @costs.last[:marginal]} < #{price} of #{@prices.inspect}") if @costs.last && @costs.last[:marginal] < price
      @costs << base.merge(:marginal => price)
    end
  end

private
  def ltm_common(charge, qty)
    raise ValidateError, "First Costs minimum must be > 1" unless @costs.first[:minimum] > 1
    @costs.unshift({ :fixed => parse_money(charge),
                    :marginal => @costs.first[:marginal],
                    :minimum => qty || @costs.first[:minimum]/2 })
  end
public

  def ltm(charge, qty = nil)
    raise ValidateError, "Can't apply less than minimum with no prices" if @costs.empty?
    qty = qty && parse_qty(qty)
    raise ValidateError.new("qty >= first qty", "#{qty} >= #{@costs.first[:minimum]}") if qty && qty >= @costs.first[:minimum]
    ltm_common(charge, qty)
  end

  def ltm_if(charge, qty)
    raise ValidateError, "Can't apply less than minimum with no prices" if @costs.empty?
    qty = qty && parse_qty(qty)
    ltm_common(charge, qty) if qty > 0 && qty < @costs.first[:minimum]
  end

  def maxqty(qty = nil)
    validate # Validate costs and prices are present
    raise ValidateError, "maxqty can only be called once" unless @costs.last[:marginal]
    @costs << { :minimum => qty ? parse_qty(qty) : [@prices.last[:minimum], @costs.last[:minimum]].max * 2 } unless @costs.empty?
  end

  def eqp(discount = 0.4)
    raise ValidateError, "Expected no costs" unless @costs.empty?
    raise ValidateError, "Expected price" if @prices.empty?
    @costs << { :minimum => @prices.first[:minimum],
      :fixed => Money.new(0), :marginal => @prices.last[:marginal] * (1.0 - discount) }
  end

  def to_hash
    { 'prices' => @prices, 'costs' => @costs }
  end
end


class VariantDesc
  # Cause uniq to consider only supplier_num
  def eql?(other); supplier_num.eql?(supplier_num); end
  def hash; supplier_num.hash; end

  include PropertyObject

  property :supplier_num, String do |s| s.strip end
  def error_id; "Variant #{supplier_num}"; end
  property :properties, Hash
  property :images, Array[ImageNodeFetch], :warn => true

  property :pricing, PricingDesc, :block => true

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
  def error_id; "Product #{supplier_num}"; end
  property :name, String do |s| s.strip end

  property :description, String, :no_pre => true do |v|
    if Array === v
      v.each do |e|
        raise PropertyError, "expected Array of String" unless String === e
        e.strip!
      end
      v.delete_if { |e| e.empty? }
      v.join("\n")
    elsif String === v
      v.strip
    else
      raise PropertyError, "expected String or Array of String"
    end
  end

  property :lead_time, LeadTimeDesc, :warn => true
  property :package, PackageDesc, :warn => true
  property :data, Hash, :nil => true
  property :pricing_params, Hash, :nil => true

  @@tags = Tag.select(:name).uniq.collect { |t| t.name }
  property :tags, Array[String], :warn => true do |array|
    array.each do |s|
      raise PropertyError, "got #{s} expected in #{@@tags.inspect}" unless @@tags.include?(s)
    end
    array
  end

  property :supplier_categories, Array do |v|
    v.each do |e|
      raise PropertyError, "expected Array of Array" unless e.is_a?(Array)
      riase PropertyError, "expected Array of non empty Array" if e.empty?
      e.each do |s|
        raise PropertyError, "expected Array of Array of String got #{v.inspect}" unless s.is_a?(String)
      end
    end
    v
  end

  property :categories, Array, :nil => true

  property :images, Array[ImageNodeFetch], :warn => true

  property :decorations, Array[DecorationDesc]

  property :variants, Array[VariantDesc] do |v|
    raise PropertyError.new("empty") if v.empty?
    v
  end

  property :properties, Hash, :no_check => true # Properties applied to all variants

  def variants_multiply_properties(list)
    return if list.empty?
    keys = list.first.keys
    raise "Must have same properties" unless list.collect { |h| h.keys }.uniq.length == keys.length
    raise "Must have unique list" unless list.uniq.length == list.length
    self.variants = self.variants.collect do |vd|
      list.collect do |h|
        v = vd.dup
        if num = keys.delete('supplier_num')
          v.supplier_num = num
        elsif post = keys.delete('postfix')
          v.supplier_num += post
        else
          v.supplier_num += keys.collect { |k| "-#{h[k]}" }.join
        end
        v.properties = v.properties.merge(h)
        v
      end
    end.flatten
  end

  def validate(import)
    # Apply Warnings
    warnings(import)

    # check presense
    validate_properties

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


    # Check if variant properties are orthoginal
    prop_hash = {}
    prop_hash.default = []
    variants.each do |variant|
      variant.properties.each do |key, value|
        prop_hash[key] += [value] unless prop_hash[key].include?(value)
      end
    end
    prop_hash.delete_if { |key, list| list.length == 1 }
    # Remove common key names (e.g. color and swatch)
    prop_hash.group_by { |key, list| list.length }.each do |len, list|
      list = list.dup
      while list.length > 1
        (key, values), tail = list.first, list[1..-1]
        tail.each do |k, vs|
          if not values.zip(vs).find do |a, b|
              properties.find { |prop| prop[key] == a && prop[k] != b }
            end
            prop_hash.delete(k)
            list.delete(tail)
          end
        end
        list.shift
      end
    end

    expected = prop_hash.inject(1) { |total, (key, list)| total * list.length }
    unless expected == variants.length
#      full_list = [{}]
#      prop_hash.each do |k, l|
#          full_list = full_list.collect { |e| l.collect { |f| e.merge(k => f) } }.flatten
#      end
#      our_list = properties.collect do |p|
#        prop_hash.keys.each_with_object({}) { |k, hash| hash[k] = p[k] }
#      end
      import.add_warning(ValidateError.new("Variants not orthoginal", "Expected: #{expected} Got: #{variants.length}"), supplier_num)
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

    replace_images = find_duplicate_images(all_images, supplier_num)

    raise ValidateError, 'No images after fetch' if (all_images - replace_images.keys).empty?

    variant_images = variants.collect do |variant|
      variant.images = variant.images.collect { |i| replace_images.has_key?(i) ? replace_images[i] : i }.compact.uniq
    end.flatten

    self.images = self.images.collect { |i| replace_images.has_key?(i) ? replace_images[i] : i }.compact.uniq - variant_images
  end

  def merge(hash)
    hash.each do |key, value|
      case key
      when /^lead_time_(\w+)$/
        self.lead_time.send("#{$1}=", value)
      when /^package_(\w+)$/
        self.package.send("#{$1}=", value) if value
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

  def self.apply(context)
    desc = self.new
    begin
      r = yield desc
      context.add_product(desc) unless r == false
    rescue ValidateError => boom
      puts "- Validate Error: #{desc.error_id}: #{boom}"
      puts boom.backtrace
      context.add_error(boom, desc.error_id)
    end
  end
end
