# -*- coding: utf-8 -*-
require 'open-uri'
require File.dirname(__FILE__) + '/../config/environment'
require File.dirname(__FILE__) + '/categories'

JOBS_DATA_ROOT = File.join(Rails.root, 'jobs/data')

def apply_decorations(supplier_name, include = nil)
  supplier = Supplier.find_by_name(supplier_name)
  raise "Unknown Supplier: #{supplier_name}" unless supplier
  
  Supplier.transaction do
    # Remove all old records
    supplier.decoration_price_groups.each do |grp|
      next if include and !include.include?(grp.technique.name)
      grp.entries.each do |entry|
        fixed = entry.fixed
        marginal = entry.marginal
        
        entry.destroy
        
        fixed.destroy if fixed and fixed.decoration_price_entry_fixed.empty?
        marginal.destroy if marginal and marginal.decoration_price_entry_marginal.empty?
      end
      grp.destroy
    end
    
    yield supplier
  end
end

# Spreadsheet Monkey Patch for access by header
class NoHeader < StandardError
end

class Spreadsheet::Excel::Row
  alias_method :old_access, :[]
  def [](idx, len = nil)
    if idx.is_a?(String) or idx.is_a?(Array)
      i = [idx].flatten.collect { |i| worksheet.header_map[i] }.compact.first
#      i = worksheet.header_map[idx]
      raise NoHeader, idx unless i
      old_access(i)
    else
      old_access(idx, len)
    end
  end

  # Match CSV interface
  def headers
    worksheet.headers
  end
  def header?(name)
    worksheet.header? name
  end
end

class Spreadsheet::Excel::Worksheet
  attr_reader :header_map
  def use_header(idx = 0)
    @header_map = {}
    row(idx).each_with_index do |cell, idx|
      next if cell.blank?
      cell = cell.strip.to_s
      if header_map[cell]
        puts "DUPLICATE HEADER: #{idx} #{cell}"
        (1..9).find do |i|
          cell = "#{cell} #{i}" if !header_map["#{cell} #{i}"]
        end
      end
      header_map[cell] = idx
    end
    @header_map
  end
  
  # Match CSV interface
  def headers
    header_map.keys
  end
  def header?(name)
    headers.include? name
  end    
end

# class RubyXL::Row
#   alias_method :old_access, :[]
#   def [](idx)
#     val = if idx.is_a?(String)
#       i = old_access(0).worksheet.header_map[idx]
#       raise NoHeader, idx unless i
#       old_access(i)
#     else
#       old_access(idx)
#     end
#     val && val.value
#   end

#   # Match CSV interface
#   def headers
#     worksheet.headers
#   end
#   def header?(name)
#     worksheet.header? name
#   end
# end


# class RubyXL::Worksheet
#   attr_reader :header_map
#   def use_header(idx = 0)
#     @header_map = {}
#     row = @sheet_data[idx]
#     (0..(row.size)).each do |idx|
#       next unless cell = row[idx]
#       next if cell.blank?
#       cell = cell.to_s.strip
#       if header_map[cell]
#         # "DUPLICATE HEADER: #{idx} #{cell}"
#         (1..9).find do |i|
#           cell = "#{cell} #{i}" if !header_map["#{cell} #{i}"]
#         end
#       end
#       header_map[cell] = idx
#     end
#     @header_map
#   end
# end




# Utility Classes for Import
class ProductRecordMerge
  def initialize(unique_properties, common_properties, null_match = nil)
    @unique_properties, @common_properties, @null_match = unique_properties, common_properties, null_match
    @unique_hash = {}
    @unique_hash.default = []
    @common_hash = {}
  end
  attr_reader :unique_properties, :common_properties, :null_match, :unique_hash, :common_hash

  def include?(id)
    common_hash[id]
  end

  def merge(id, object, options = {})
    if chash = common_hash[id]
      common_properties.each do |name|
        raise "Mismatch: #{id} #{name} #{chash[name].inspect} != #{object[name].inspect}" unless chash[name] == (object[name] === null_match ? nil : object[name])
      end
      options[:common].each do |key, value|
        raise "Mismatch: #{id} #{name} #{chash[name].inspect} != #{value}" unless chash[key] == value
      end if options[:common]
    else
      chash = common_properties.each_with_object({}) do |name, hash|
        hash[name] = object[name] unless object[name] === null_match
      end
      common_hash[id] = chash.merge(options[:common] || {})
    end

    uhash = unique_properties.each_with_object({}) do |name, hash|
      hash[name] = object[name]
    end
    if unique_hash[id] && unique_hash[id].include?(uhash)
      str = "Duplicate: #{id} #{uhash.inspect} in #{unique_hash[id].inspect}" 
      options[:allow_dup] ? puts(str) : raise(str)
    else
      unique_hash[id] += [uhash]
    end
    uhash
  end

  def each
    unique_hash.each do |id, uhash|
      chash = common_hash[id]
      yield id, uhash, chash
    end
  end
end

class ImageNode
  def initialize(id, tag = nil)
    @id = id
    @tag = tag
  end 

  attr_reader :id, :tag

  include Comparable
  def <=>(r); id <=> r.id; end
  def hash; id.hash; end
  def eql?(r); id.eql?(r.id); end

  def to_s; id; end

  def inspect; id.inspect; end
end

module FileCommon
  def filename
    File.basename(path)
  end

  def extname
    File.extname(path)
  end

  def get(time = nil)
    return nil unless p = get_path(time)
    File.open(p)
  end

  def size(time = nil)
    begin
      File.size(get_path(time))
    rescue
      return nil
    end
  end
end

class ImageNodeFile < ImageNode
  include FileCommon

  def initialize(id, path, tag = nil)
    super id, tag
    @path = path
  end
  attr_reader :path

  def get_path(time = nil); path; end

  def inspect
    "#{id}:#{path}"
  end
end

module WebFetchCommon
  include FileCommon

  @@cache_dir = CACHE_ROOT

  attr_reader :uri

  def ==(other)
    @uri == other.uri
  end

  def uri_tail
    @uri.respond_to?(:request_uri) ? @uri.request_uri : @uri.path
  end

  def path_tail
    base = "/#{@uri.host}/#{uri_tail}"
    base = "#{base}/index.html" if @uri.path.empty? or @uri.path[-1..-1] == '/'
    base
  end

  def path
    "#{@@cache_dir}#{path_tail}"
  end

  def fetch?(time = nil)
    if File.exists?(path)
      return false unless time

      stat = File.stat(path)
      if stat.file? and (stat.mtime > time)
        return false
      end
    end
    true
  end

  def get_path(time = nil)
    return path unless fetch?(time)
    
    begin
      puts "Fetch: #{@uri} => #{path}"
      pbar = nil
      f = @uri.open(:content_length_proc => lambda {|t|
                      if t && 0 < t
                        name = /\/(\w+)(?:\.(\w+))?$/ =~ uri_tail ? $1 : uri_tail
                        pbar = ProgressBar.new(name, t)
                        pbar.file_transfer_mode
                      end },
                    :progress_proc => lambda {|s|
                      pbar.set s if pbar
                    })
      return nil if f.length == 0

      FileUtils.mkdir_p(File.split(path).first)

      if f.respond_to?(:path)
        FileUtils.mv(f.path, path)
      elsif f.respond_to?(:save_as)
        f.save_as path
      else
        File.open(path, "w:#{f.external_encoding}") { |file| file.write(f.read) }
      end
      puts
    rescue OpenURI::HTTPError, URI::InvalidURIError, Errno::ETIMEDOUT => e
      puts " * #{e.class} : #{@uri}"
      return nil
    end

    path
  end

  def get_doc
    return nil unless path = get_path
    Nokogiri::HTML(open(path))
  end
end

class ImageNodeFetch < ImageNode
  include WebFetchCommon

  def initialize(id, uri, tag = nil)
    super id, tag
    @uri = URI.parse(uri.gsub(' ', '%20'))
  end

  def inspect
    "#{id}:#{uri}"
  end
end

class WebFetch
  include WebFetchCommon
  cattr_accessor :cache_dir

  def initialize(uri)
    @uri = URI.parse(uri.gsub(' ', '%20'))
  end
end

class GenericImageFetch < WebFetch

end

# Used in validate_after in ProductDesc and validate between in GenericImport
def find_duplicate_images(images, id = nil)
  replace_images = {}
  
  dup_hash = {}
  dup_hash.default = []
  images.each do |image|
    unless size = image.size
      replace_images[image] = nil
      puts "  No Image: #{id.inspect}\n"
      next
    end
    
    match = nil
    if ref = dup_hash[size]
      if match = ref.find { |r| File.stat(r.path) == File.stat(image.path) }
        puts "  Existing Duplicate Image: #{id} #{match.path}\n"
      elsif match = ref.find { |r| FileUtils.compare_file(r.path, image.path) }
        puts "  Duplicate Image: #{id} #{size} #{ref.inspect} #{image.inspect}\n"
        FileUtils.ln(match.path, image.path, :force => true)
      end
      replace_images[image] = match if match
    end

    dup_hash[size] += [image] unless match
  end

  replace_images
end

class ValidateError < StandardError
  def initialize(aspect, value = nil)
    @aspect, @value = aspect, value
  end
  attr_reader :aspect, :value

  def mark_duplicate!
    @aspect = "DUP #{@aspect}"
  end
  
  def to_s
    "#{aspect}: #{value}"
  end
end


# New Product Record Interface
require_relative 'product_description'

class ProductApply
  def initialize(supplier, current, previous = nil)
    @supplier, @current, @previous = supplier, current, previous
  end
  attr_reader :supplier, :record, :current, :previous
  
  def apply
    product_log = ''

    @changed = ProductDesc.properties
    @changed = @changed.find_all do |prop|
      current.instance_variable_get("@#{prop}") != previous.instance_variable_get("@#{prop}")
    end if previous

    product_new = nil
    begin
      Product.transaction do
        @record = supplier.get_product(current.supplier_num)
        product_new = record.new_record?

        @changed.each do |prop|
          product_log += send("apply_#{prop}",
                              current.instance_variable_get("@#{prop}"),
                              previous && previous.instance_variable_get("@#{prop}"))
        end
        
        unless product_log.empty?
          record.updated_at_will_change! # Update updated_at
        end
        record.deleted = false
        record.save!
      end
    rescue Exception
      puts current.inspect
      puts "Log: \n" + product_log if product_new
      raise
    ensure
      # Log it
      if product_new
        puts " Product: #{current.supplier_num} (M#{record.id}) (NEW)"
      elsif !product_log.empty?
        puts " Product: #{current.supplier_num} (M#{record.id})\n" + product_log
      end
    end

    product_log.empty? ? nil : record
  end

  %w(supplier_num name description data).each do |name|
    define_method "apply_#{name}" do |curr, prev|
      return '' if (old = record.send(name)) == curr
      record[name] = curr
      "  #{name}: #{old.inspect} => #{curr.inspect}\n"
    end
  end

  %w(package lead_time).each do |name|
    properties = Kernel.const_get("#{name.classify}Desc").properties
    define_method "apply_#{name}" do |curr, prev|
      properties.collect do |prop|
        val = curr && curr.send(prop)
        unless (prev && val == prev.send(prop)) ||
            ((old = record["#{name}_#{prop}"]) == val)
          record["#{name}_#{prop}"] = val unless val.nil?
          "  #{name}.#{prop}: #{old.inspect} => #{val.inspect}\n"
        end
      end.compact.join
    end
  end

  def apply_tags(curr, prev)
    record.save! if record.new_record? # Allocate ID
    record.set_tags(curr || [])
  end

  def apply_decorations(curr, prev)
    record.set_decorations(curr)
  end

  def apply_categories(curr, prev)
    record.set_categories(curr.collect { |a| a.collect { |b| b[0...32] } })
  end
  def apply_supplier_categories(curr, prev); ''; end

  def apply_pricing_params(curr, prev); ''; end

  def apply_images(curr, prev)
    all_images = (curr + current.variants.collect { |v| v.images }).flatten.compact.uniq
    record.delete_images_except(all_images) + record.set_images(curr)
  end

  def apply_properties(curr, prev)
    @changed << 'variants' unless @changed.include?('variants')
    ''
  end
  alias_method :apply_pricing, :apply_properties

  def apply_variants(curr, prev)
    new_price_groups, new_cost_groups = [], []

    product_log = ''
       
    # Process Variants
    variant_records = curr.collect do |vd|
      variant_log = ''
      variant_record = record.get_variant(vd.supplier_num)
      variant_new = variant_record.new_record?
      variant_record.save! if variant_new

      # Fetch Images
      variant_log << variant_record.set_images(vd.images)
          
      # Properties
      properties = (current.instance_variable_get('@properties') || {}).merge(vd.properties)
      properties.each do |name, value|
        next if name == 'swatch'
        value = nil if value.blank?
        if value.is_a?(Hash)
          k = value.keys.collect { |s| s.to_s[0].upcase }
          raise "Non Unique Key" unless k.length == k.uniq.length
          value = value.collect { |k, v| "#{k.to_s[0].upcase}:#{v}" }.sort.join(',') 
        end
        variant_record.set_property(name, value, variant_log)
      end
      
      # Swatch Property
      if img = vd.properties['swatch']
        if swatch_prop = variant_record.set_property('swatch', img.id, variant_log)
          i = img.get
          swatch_prop.image = i
          swatch_prop.save!
        end
      end

      # Delete Properties
      variant_record.delete_properties_except(properties.keys, variant_log)
          
      # Match groups to variant list.  Ensure cost and price lists match
      pricing = current.instance_variable_get('@pricing') || vd.pricing
      if pg = new_price_groups.zip(new_cost_groups).find do |(dp, vp), (dc, vc)|
          dp == pricing.prices and dc == pricing.costs
        end
        pg[0][1] << variant_record
        pg[1][1] << variant_record
      else
        new_price_groups << [pricing.prices, [variant_record]]
        new_cost_groups << [pricing.costs, [variant_record]]
      end

      # Log it
      if variant_new
        product_log << "  Variant: #{vd.supplier_num} (NEW)\n"
      elsif !variant_log.empty?
        product_log << "  Variant: #{vd.supplier_num}\n"
        product_log << variant_log
        variant_record.save! # Update updated_at
      end
      
      variant_record
    end
       
    # Remove variants
    (record.variants - variant_records).each do |variant_record|
      if variant_record.order_item_variants.empty? and
          (variant_record.price_group_order_items_count == 0)
        product_log << "  Deleted Variant: #{variant_record['supplier_num']} (#{variant_record.id})\n"
        variant_record.destroy
      else
        product_log << "  Marked Deleted Variant: #{variant_record['supplier_num']} (#{variant_record.id})\n"
        variant_record.deleted = true
        variant_record.save!
      end
    end

    recache_prices = false
    
    [[new_price_groups, supplier.price_source],
     [new_cost_groups, nil]].each do |dst, source_id|
      log = record.set_prices(source_id, dst)
      recache_prices = true unless log.empty?
      product_log += log
    end
    
    # Check shit
    record.variants.each do |variant|
      srcs = variant.price_groups.collect { |g| g.source }
      unless srcs.length == srcs.uniq.length
        puts "#{variant.id}: #{variant.price_groups.inspect}"
        raise "Multiple price groups from the same source" 
      end
    end
        
    if recache_prices
      pc = PriceCollectionCompetition.new(record)
      pc.calculate_price(current.pricing_params || {})
    end
    
    record.association(:variants).target = variant_records

    product_log
  end
end

class GenericImport
  @@cache_dir = File.join(CACHE_ROOT, "jobs")
  
  def initialize(supplier)
    @supplier_name = supplier
    [supplier].flatten.each do |name|
      @supplier_record = ((@supplier_record && @supplier_record.children) || Supplier).find_by_name(name)
      raise "Supplier not found: #{supplier.inspect}" unless @supplier_record
    end
#    unless @supplier_record
#      @supplier_record = Supplier.create(:name => supplier,
#                      :price_source => PriceSource.create(:name => supplier))
#    end
    @decoration_techniques = DecorationTechnique.find(:all).inject({}) { |h, i| h[i.name] = i; h }
    @product_list = []

    @invalid_prods = {}
    @warning_prods = {}

    @invalid_values = {}
    @warning_values = {}
  end

  def set_standard_colors(colors = nil)
    colors = imprint_colors unless colors
    if @supplier_record.standard_colors != colors
      color = colors.find { |e| !PantoneColor.find(e) }
      raise "Unknown color: #{color}" if color
      @supplier_record['standard_colors'] = colors.join(',')
      @supplier_record.save!
    end
  end
  
  def get_product(supplier_num)
    product_record = @supplier_record.get_product(supplier_num)
    if product_record.new_record?
      product_record.name = ''
      product_record.deleted = true
      product_record.save!
      puts "Allocating #{supplier_num} => #{product_record.id}"
    end
    product_record
  end
    
  def cache_file(name)
    File.join(@@cache_dir, name)
  end
  
  def cache_exists(file_name)
    return nil unless File.exists?(file_name)
    begin
      File.ftype(file_name) == "file"
    rescue
      nil
    end
  end
  
  def cache_read(file_name)
    puts "Reading Cache from #{file_name}"
    File.open(file_name) { |f| Marshal.load(f) }
  end
  
  def cache_write(file_name, res)
    File.open(file_name,"w") { |f| Marshal.dump(res, f) }
  end
  
  # Only used in primeline
  def cache_marshal(name, predicate = nil)
    file_name = cache_file(name)
    if cache_exists(file_name)
      unless predicate and [predicate].flatten.find { |p| File.exists?(p) && (File.mtime(p) > File.mtime(file_name)) }
        return cache_read(file_name)
      end
    end

    res = yield
    cache_write(file_name, res)
    res
  end

  def validate_interproduct
    swatches = @product_list.collect { |pd| ([pd.properties['swatch']] +  pd.variants.collect { |pv| pv.properties['swatch'] }).compact }.flatten.uniq
    return if swatches.empty?

    puts "Swatch DeDup START <<"

    replace_images = find_duplicate_images(swatches)

    @product_list.each do |pd|
      swatch = pd.properties['swatch']
      pd.properties['swatch'] = replace_images[swatch] if replace_images.has_key?(swatch)
      pd.variants.each do |pv|
        swatch = pv.properties['swatch']
        pv.properties['swatch'] = replace_images[swatch] if replace_images.has_key?(swatch)
      end
    end
    puts ">> Swatch DeDup STOP: #{swatches.size} #{replace_images.size}"
  end

  def run_parse
    init_time = Time.now
    puts "#{@supplier_record.name} parse start at #{init_time}"
    @product_hash = {}
    parse_products
    @product_list = @product_hash.values
    @product_hash = nil # Don't need hash anymore
    mid_time = Time.now
    puts "#{@supplier_record.name} parse stop at #{mid_time} for #{mid_time - init_time}s #{@product_list.length}"     
    unless ARGV.include?('nopost')
      @product_list.delete_if do |pd|
        begin
          pd.validate_after
        rescue => boom
          if boom.is_a?(ValidateError)
          add_error(boom, pd.supplier_num)
            next true # Do Delete
          else
            raise
          end
        end
        false
      end
      
      validate_interproduct
    end

    stop_time = Time.now
    puts "#{@supplier_record.name} validate stop at #{stop_time} for #{stop_time - mid_time}s #{@product_list.length}"
  end

  def parse_cache_filename
    "#{@supplier_record.name}_parse"
  end

  def fetch_parse?
    if @src_urls
      time = Time.now - 1.day
      fetched = false
      @src_files = [@src_urls].flatten.collect do |url|
        wf = WebFetch.new(url)
        fetched = true if wf.fetch?(time)
        wf.get_path(time)
      end
      return true if fetched
    end

    file_name = cache_file(parse_cache_filename)
    !cache_exists(file_name) || (File.mtime(file_name) < (Time.now - 1.day))
  end
  
  def run_parse_cache
    file_name = cache_file(parse_cache_filename)
    if fetch_parse? or ARGV.include?('parse') or !cache_exists(file_name)
      run_parse
      cache_write(file_name, @product_list)
    else
      @product_list = cache_read(file_name)
    end
  end
    
  def run_transform(transform = nil)
    init_time = Time.now
    print "Applying Category Transform: "
    trans = transform || CategoryTransform.new([@supplier_name].flatten.first)
    puts "APPLY(#{trans.rules_count}) "
    @product_list.each do |pd|
      trans.apply_rules(pd)
    end
    trans.status unless transform
    puts "DONE in #{Time.now - init_time}s"
  end
  
  def run_apply_cache(cleanup = true)
    file_name = cache_file("#{@supplier_record.name}_database")
    if cache_exists(file_name)
      last_data = cache_read(file_name)
    else
      puts "No Database Cache: #{file_name}"
      last_data = {}
    end
    
    begin
      # Find Current
      supplier_num_set = Set.new
      update_pd_list = @product_list.find_all do |pd|
        supplier_num_set.add(pd.supplier_num)
        last_data[pd.supplier_num] != pd
      end


      # Print Stats
      [['Product Warnings', @warning_prods, @warning_values],
       ['Invalid Products', @invalid_prods, @warning_values]].each do |name, prods, values|
        puts name unless prods.empty?
        prods.each do |aspect, list|
          puts "  #{aspect} (#{list.length}): "
          if list.length * 2 > supplier_num_set.length
            negl = supplier_num_set.to_a - list
            puts "    Items: ALL - #{negl.join(', ')}"
          else
            puts "    Items: #{list.join(', ')}"
          end
          if values[aspect]
            val_list = values[aspect].find_all { |s, c| c > 1 }.sort_by { |s, c| c }.reverse
            puts "    Values: #{val_list.collect { |s, c| "#{s}(#{c})" }.join(', ')}" unless val_list.empty?
          end
        end
      end

      
      common_count = 0
      delete_id_list = []
      delete_sup_list = []
      current_id_list = @supplier_record.products.select([:id, :supplier_num]).collect do |p|
        if supplier_num_set.delete?(p.supplier_num)
          common_count += 1
        elsif !(Rails.env.production? && @invalid_prods.values.flatten.index(p.supplier_num))
          delete_id_list << p.id 
          delete_sup_list << p.supplier_num
        end
        p.id
      end

      puts "Deleted Products: #{delete_sup_list.join(', ')}"

      total = @product_list.length
      puts "Update Stats:"
      puts "   Total:#{'%5d' % total}"
      { '   New' => supplier_num_set.size,
        'Change' => change_count = update_pd_list.size - supplier_num_set.size,
        'Delete' => delete_id_list.length }.each do |name, count|
        puts "  #{name}:#{'%5d' % count} (#{'%0.02f%' % (count * 100.0 / total)})"
      end

      if (change_count * 10 > total) || (delete_id_list.length * 20 > total)
        if ARGV.include?('override')
          puts "Override excessive change"
        else
          raise "Aborting. To many changes"
        end
      end

      # Apply Updates
      update_pd_list.each do |pd|
        pa = ProductApply.new(@supplier_record, pd, last_data[pd.supplier_num])
        pa.apply
        last_data[pd.supplier_num] = pd
      end
      
      # Cleanup
      delete_id_list.each do |product_id|
        product_record = Product.find(product_id)
        puts " Deleted Product: #{product_record['supplier_num']} (M#{product_record.id})"
        product_record.delete
      end if cleanup
    ensure
      cache_write(file_name, last_data)
    end
  end

  def purge_image_cache(common_path)
    puts "Finding Good Images"
    keep_images = @product_list.collect do |prod|
      (prod.images + prod.variants.collect { |v| v.images }).flatten.collect do |img|
        img.get_path
      end.uniq
    end.flatten.uniq

    puts "Checking common path"
    keep_images.each do |path|
      raise "Non Common Path: #{path} of #{common_path}" unless common_path == path[0...common_path.length]
    end

    puts "Finding Excess"
    all = Dir["#{common_path}/**/*.*"].collect { |s| s.gsub(/\/+/, '/') }

    unenumerated = keep_images - all
    delete = all - keep_images

    puts "Keep: #{keep_images.length} Delete: #{delete.length} Unenumerated: #{unenumerated.length}"
    delete.each do |f|
      puts " Delete: #{f}"
      FileUtils.rm(f)
    end
  end

  def run_all(cache = true)
    cache ? run_parse_cache : run_parse
    run_transform
    run_apply_cache
  end
  
  # For debuging
  def run_apply_for_product(num)
    @product_list.each do |pd|
      next unless pd.supplier_num == num
      apply_product(pd)
    end
  end

  def add_error(boom, id)
    puts "+ #{id}: #{boom}"  unless ARGV.include?('nowarn')
    @invalid_prods[boom.aspect] = (@invalid_prods[boom.aspect] || []) + [id]
    @invalid_values[boom.aspect] ||= (h = {}; h.default = 0; h)
    @invalid_values[boom.aspect][boom.value] += 1
  end

  def add_warning(boom, id = @supplier_num || @product_description.supplier_num)
    puts "* #{id}: #{boom}"  unless ARGV.include?('nowarn')
    @warning_prods[boom.aspect] = (@warning_prods[boom.aspect] || []) + [id]
    @warning_values[boom.aspect] ||= (h = {}; h.default = 0; h)
    @warning_values[boom.aspect][boom.value] += 1
  end

  def warning(aspect, description = nil, id = @supplier_num || @product_description.supplier_num)
    add_warning(ValidateError.new(aspect, description), id)
  end
  
  def has_product?(supplier_num)
    @product_hash[supplier_num]
  end

  def add_product(object)
    begin
      if object.is_a?(ProductDesc)
        pd = object # Remove this eventually
      else
        pd = ProductDesc.new(object)
      end
      pd.validate(self)
      if prev = @product_hash[pd.supplier_num]
        changed = ProductDesc.properties.find_all do |prop|
          pd.instance_variable_get("@#{prop}") != prev.instance_variable_get("@#{prop}")
        end
        if changed.delete('supplier_categories')
          pd.supplier_categories += prev.supplier_categories
        end
        if changed.delete('tags')
          pd.tags += prev.tags
        end
        unless changed.empty?
          warning "Duplicate Product", changed.inspect
          changed.each do |prop|
            l = pd.send(prop)
            r = prev.send(prop)
            if l.is_a?(Array) && l.is_a?(Array)
              c = l & r
              l -= c
              r -= c
            end
            puts "  #{prop}: #{l} != #{r}"
          end
        end
      end
      @product_hash[pd.supplier_num] = pd
    rescue => boom
      puts "+ Validate Error: #{pd && pd.supplier_num}: #{boom}"
      if boom.is_a?(ValidateError)
        add_error(boom, pd && pd.supplier_num)
      else
        puts boom.backtrace
        @invalid_prods['Other'] = (@invalid_prods[boom.to_s] || []) + [pd ? pd.supplier_num : 'unknown']
        @invalid_values['Other'] ||= Set.new
        @invalid_values['Other'] << boom.value if boom.respond_to?(:value)
      end
    end
  end
  
  def each_product
    @product_list.each { |p| yield p }
  end
  
private
  @@number_regex = 
    /(?<whole>\d{1,3})?
     (?:(?<deci>\.\d{1,16}) |
        (?:(?: (?:^|\s+|-) (?<numer>\d{1,2}) )? \s*[\/∕]\s* (?<denom>\d{1,2}) ) |
        (?:(?:^|\s+) (?<sym>[⅛¼⅓⅜½⅝¾⅞]) ) |
        (?<=\d) )  # Postive lookbehind to match 'whole' alone
     \s*(?<dim>[\"”]|(?:\&quot;)|(?:yards?)|(?:mm))?\s*/xi
  private
  def number_from_regex(m)
    num = 0.0
    num = Float(m[:whole]) if m[:whole]
    num += Float(m[:deci]) if m[:deci]
    if m[:numer]
      num += Float(m[:numer])/Float(m[:denom])
    elsif m[:denom]
      num /= Float(m[:denom])
    end
    num += case m[:sym]
           when '⅛'; 0.125
           when '¼'; 0.25
           when '⅓'; 1.0/3.0
           when '⅜'; 0.375
           when '½'; 0.5
           when '⅝'; 0.625
           when '⅔'; 2.0/3.0
           when '¾'; 0.75
           when '⅞'; 0.875
           end if m[:sym]
    case m[:dim]
      when /^yard/
      num *= 36
      when /^mm/
      num *= 0.0393701
    end
    num
  end
  public

  def parse_number(string)
   unless m = /^#{@@number_regex}$/.match(string.strip)
     warning 'Parse Number', "RegEx mismatch: #{string}"
     return
   end
    number_from_regex(m)
  end

  # g for gussetted in adbag?
  @@component_regex = /#{@@number_regex}(?<aspect>wide|width|w|high|height|h|long|length|l|diameter|diam?\.?|square|sq\.?|d|depth|round)?/i
  def parse_dimension(string, pedantic = false)
    list = string.strip.split(/x/i).collect do |part|
      unless m = /^#{@@component_regex}$/.match(part.strip)
        warning 'Parse Dimension', "RegEx mismatch: #{part.inspect}"
        return if pedantic
      end
      m
    end.compact
    aspects = parse_aspects(list, string, pedantic)
    return nil unless aspects
    if [:height, :width, :length].count { |a| aspects[a] } < 2
      warning 'Parse Dimension', "Missing two aspects: #{string}"
      return if pedantic
    end
    aspects
  end

  l = @@component_regex.to_s.gsub(/\?<(.+?)>/,'?<l_\1>')
  r = @@component_regex.to_s.gsub(/\?<(.+?)>/,'?<r_\1>')
  @@area_regex = /^(?<left>.*?)\s*#{l}(?:\s*x?\s*#{r})?\s*(?<right>.*)$/i
  def parse_area(string, pedantic = false)
    unless m = @@area_regex.match(string.strip)
      warning 'Parse Area', string.inspect
      return
    end
    parts = {}
    other = {}
    m.names.each do |name|
      first, second = name.split('_')
      next if (val = m[name]).blank?
      if second 
        parts[first] ||= {}
        parts[first][second.to_sym] = val
      else
        other[name.to_sym] = val
      end
    end
    aspects = parse_aspects([parts['l'], parts['r']].compact, string, pedantic)
    aspects.merge!(other) if aspects
    aspects
  end

  def parse_location(string)
  end

  def parse_aspects(list, string, pedantic = false)
    aspects = {}
    no_aspect = nil
    list.each do |m|
      num = number_from_regex(m)
      if num == 0.0
        warning 'Parse Area', 'zero'
        next
      end

      aspect = case m[:aspect]
               when /^w/i;       :width
               when /^h/i;       :height
               when /^l/i;       :length
               when /^dia/i;     :diameter
               when /^round/i;   :diameter
               when /^d/i;       :depth
               when /^sq/i; :square
               end
      if aspect
        if no_aspect
          warning 'Parse Area', "Without and With aspect: #{string}"
          return if pedantic
        end
        no_aspect = false
        if aspects.has_key?(aspect)
          warning 'Parse Area', "Duplicate Aspect: #{string}"
          return if pedantic

          unless aspect = [:width, :height, :length].find { |s| !aspects.has_key?(s) }
            warning 'Parse Area', "All aspects covered on duplicate"
            return
          end
        end
      else
        if no_aspect == false
          warning 'Parse Area', "With and Without aspect: #{string}"
          return if pedantic
        end
        no_aspect = true
        unless aspect = [:width, :height, :length].find { |s| !aspects.has_key?(s) }
          warning 'Parse Area', "All aspects covered"
          return
        end
        aspect = :length if num > 12.0 and !aspects.has_key?(:length)
      end

      aspects[aspect] = num
    end

    if aspects[:square]
      if aspects.length != 1
        warning 'Parse Area', "Didn't Expect other aspects on square: #{string}"
        return
      end
      aspects[:height] = aspects[:width] = aspects.delete(:square)

      return aspects
    end

    if aspects[:diameter] 
      if aspects.length != 1
        warning 'Parse Area', "Didn't Expect other aspects on diameter: #{string}"
        return
      end

      return aspects
    end

    if depth = aspects.delete(:depth)
      warning 'Parse Area', 'Excessive aspects covered' if aspects.length > 3
      if aspects.empty?
        aspects[:diameter] = depth
        return aspects
      else
        [:width, :height, :length].find do |a|
          next if aspects[a]
          aspects[a] = depth
        end
      end
    end
    
    aspects
  end

  crn = @@component_regex.to_s.gsub(/\?<.+?>/,'?:').gsub(/\)\?\)$/,'))')
  @@multi_area_regex = /\s*(?:([A-Z\- ]+):)?\s*(?:([A-Z\- ]+):)?\s*(?:\((.+?)\):?)?\s*(#{crn}(?:\s*x\s*#{crn})?)\s{0,2}(?:\(?([A-Z0-9][A-Z0-9 ]*)(?:$|[.!?)]|(?:  )))?/i

  def parse_areas(string, seperator = 'or')
    return [] if string.blank?
    locations = []
    string.gsub(' ',' ').split(seperator).each do |str|
      str.scan(@@multi_area_regex).each do |a, b, c, dim, d|
        loc = [a, b, c, d].compact.collect { |s| s.strip }
        decoration = nil
        loc.delete_if do |str|
          if dec = decoration_map[str.downcase]
            warning "Duplicate decoration" if decoration
            decoration = dec
          end
        end if respond_to?(:decoration_map)
        loc = block_given? ? yield(loc) : loc.join(', ')
        if area = parse_dimension(dim)
          locations += [decoration].flatten.collect do |dec|
            { :technique => dec, :location => loc }.merge(area)
          end
        else
          warning "Unkown Decoration", "#{decoration.inspect}: #{area.inspect} (#{loc}) [#{dim.inspect} #{a.inspect} #{b.inspect} #{c.inspect}]"
        end
      end
    end
    locations
  end
  
  @@upcases = %w(AM FM MB GB USB)
  @@downcases = %w(in with)
  def convert_name(str)
    str.split(' ').collect do |c|
      if @@upcases.index(c.upcase)
        c.upcase
      elsif @@downcases.index(c.downcase)
        c.downcase
      else
        c.capitalize
      end
    end.join(' ')
  end

  def clean_ftp_images(image_list)
    puts "Clean Images:"
    keep_files = image_list.values.collect { |e| e.collect { |node, var_id| node.path } }.flatten

    common = keep_files.first.split('/').compact
    keep_files[1..-1].each do |path|
      common = common[0...path.split('/').zip(common).index { |a, b| a != b}]
    end

    common = common.join('/')
    puts "  #{keep_files.length} valid files all in #{common}"

    all = Dir["#{common}/**/*.*"]

    delete = all - keep_files
    #raise "Bad Enumeration" if delete.length != all.length - keep_files.length
    puts "  #{delete.length} to delete = #{all.length} - #{keep_files.length}"
    
    FileUtils.rm(delete)
  end

  # Used by Leeds, PrimeLine and Norwood
  def get_ftp_images(server, paths = nil, recursive = nil)
#    cache_marshal("#{@supplier_record.name}_imagelist") do
    directory_file = cache_file("#{@supplier_record.name}_directorylist")
    @directory = cache_exists(directory_file) ? cache_read(directory_file) : {}
    begin
      require 'net/ftp'
      require 'net/ftp/list'
      products = {}
      products.default = []

      if server.is_a?(Hash)
        ftp = Net::FTP.new(server[:server])
        ftp.login(server[:login], server[:password])
        host = "#{server[:login]}:#{server[:password]}@#{server[:server]}"
      else
        ftp = Net::FTP.new(host = server)
        ftp.login
      end

      paths = [paths].flatten
      paths.each do |path|
        if @directory[path]
          list = @directory[path]
        else
          puts "  ftp://#{host}/#{path}"
          ftp.chdir('/'+path) if path
          list = @directory[path] = ftp.list
        end

        list.each do |e|
          entry = Net::FTP::List.parse(e)
          if entry.file?
            img_id, prod_id, var_id, tag = yield path, entry.basename
            url = "ftp://#{host}/#{path && (path+'/')}#{entry.basename}"
            if prod_id
              products[prod_id] += [[ImageNodeFetch.new(img_id, url, tag), var_id]]
            else
              puts "    Unknown: #{url}"
            end          
          else
            paths << "#{path}/#{entry.basename}" if recursive and ((recursive == true) or (recursive === (path+'/'+entry.basename)))
          end
        end
      end

      products.default = nil

      clean_ftp_images(products) if ARGV.include?('clean')

      return products
    ensure
      cache_write(directory_file, @directory)
    end
  end

  def match_colors(colors, options = {}, supplier_num = @supplier_num || @product_description.supplier_num)
    image_list = (@image_list[supplier_num] || [])

    match_image_colors(image_list, colors, options, supplier_num)
  end

  def match_image_colors(image_list, colors, options = {}, supplier_num = @supplier_num || @product_description.supplier_num)
#    if colors.length == 1
#      return { colors.first => image_list.collect { |image, suffix| image } }
#    end

    if colors.empty?
      list = image_list.collect { |image, suffix| image }
      return [{}, {}] if list.empty?
      return [{ nil => list }, {}]
    end

    image_map = {}
    supplier_map = {}

    image_map.default = []

    multiple_map = {}
    multiple_map.default = []

    if options[:prune_colors]
      strings = colors.collect { |s| s.split(/([^A-Z]+)/i) }
      common_tok = remove_common_prefix_postfix(strings)
      common_str = common_tok.collect { |s| s.join }
      common_tok = common_tok.collect { |t| t.collect { |s| s.blank? ? nil : s.downcase }.compact.uniq }
      unless common_str == colors
        puts " Prune: #{colors.inspect} => #{common_str.inspect}"
      end
      match_list = colors.zip(common_str, common_tok)
    else
      common_str = colors.collect { |c| [c] }
      match_list = colors.zip(colors, common_str)
    end


    # Exact Suffix Match then remove color from furthur match
    remove_matches = []
    image_list.delete_if do |image, suffix|
      if suffix.blank?
        image_map[nil] += [image]
        next true
      end
      
      list = nil
      list = match_list.find_all { |id, c, t| color_map[c.downcase] && [color_map[c.downcase]].flatten.include?(suffix) } if respond_to?(:color_map)
      unless list
        hash = {}
        hash.default = []
        match_list.each do |elem|
          id, str, tok = elem

          sep = 0
          last = nil
          score = 100 * tok.count do |s| 
            next unless i = suffix.downcase.index(s)
            sep += (last - i).abs if last
            last = i + s.length
          end
          score -= 10 * tok.length
          score -= sep

          hash[score] += [elem]
        end
        list = hash.keys.max > 0 ? hash[hash.keys.max] : []
      end
      if list.length > 1
        multiple_map[image] += list
      elsif list.length == 1
        elem = list.first
        id = elem.first
        image_map[id] += [image]
        if supplier_map[id]
          warning 'Image Supplier Num Mismatch', "#{id.inspect} => #{supplier_map[id]} != #{suffix}" unless supplier_map[id] == suffix
        else
          supplier_map[id] = suffix
        end
        remove_matches << elem unless remove_matches.include?(elem)
        true
      end
    end
    match_list -= remove_matches

    if respond_to?(:color_map)      
      # Component Suffix Match
      mapped = match_list.collect do |id, color, tok|
        names = color_map.keys.find_all { |c| [c].flatten.find { |d| color.downcase.include?(d) } }
        names = names.find_all { |n| !names.find { |o| (o != n) and o.include?(n) } }
        names.sort_by! { |n| color.downcase.index(n) }
        results = ['']
        names.each do |n| 
          results = [color_map[n]].flatten.collect do |c|
          results.collect { |r| r + c }
          end
          results.flatten!
        end
        results
      end
      
      remove_matches = []
      image_list.delete_if do |image, suffix|
        if list = mapped.find { |sufs| sufs.include?(suffix) }
          elem = match_list[mapped.index(list)]
          id = elem.first
          image_map[id] += [image]
          if supplier_map[id]
            raise "Supplier Num mismatch #{supplier_num}: #{id.inspect} => #{supplier_map[id]} != #{suffix}" unless supplier_map[id] == suffix
          else
            supplier_map[id] = suffix
          end
          remove_matches << elem unless remove_matches.include?(elem)
          true
        end
      end
      match_list -= remove_matches
    end


    image_list.each do |image, suffix|
      reg = Regexp.new(suffix.split('').collect { |s| [s, '.*'] }.flatten[0..-2].join, Regexp::IGNORECASE)
      list = match_list.find_all do |id, color, tok|
        (reg === color)
      end.compact

      if list.length > 1
        multiple_map[image] += list
      elsif list.length == 1
        id = list.first.first
        image_map[id] += [image]
        unless supplier_map[id] or supplier_map.values.include?(suffix)
          supplier_map[id] = suffix
        end
        next
      end

      image_map[nil] += [image] # Place every remaining image in image_map[nil]
    end

    unless multiple_map.empty?
      matched = image_map.keys
      multiple_map.delete_if do |image, list|
        list = list.find_all { |id, c, t| !matched.include?(id) }
        if list.length == 1
          image_map[list.first.first] += [image]
          image_map[nil].delete(image)
          puts " PostMatch: #{list.first.first}: #{image}"
          true
        end
      end

      unless multiple_map.empty?
        warning("Image Multiple Match", 
                multiple_map.collect do |image, list|
                  #image_map[nil] += [image] # THERE IS A BUG HERE
                  "#{image} => #{list.inspect}"
                end.join(', '))
      end
    end

    image_map.default = nil

    [image_map, supplier_map]
  end

  def remove_common_prefix_postfix(strings)
    return strings if strings.length <= 1

    # Prefix
    shortest = strings.min_by(&:length)
    maxlen = shortest.length
    maxlen.downto(1) do |len|
      substr = shortest[0...len]
      if strings.all? { |s| s[0...len] == substr }
        strings = strings.collect { |s| s[len..-1] }
        break
      end
    end

    # Postifx
    shortest = strings.min_by(&:length)
    maxlen = shortest.length
    maxlen.downto(1) do |len|
      substr = shortest[-len..-1]
      if strings.all? { |s| s[-len..-1] == substr }
        puts "Len: #{len}"
        strings = strings.collect { |s| s[0...-len] }
        break
      end
    end

    strings
  end

  # Magnetgroup has column extra color pricing, should implement
  def get_decoration(technique, fixed, marginal, options = {})
    @decoration_set ||= Set.new
    fixed = Money.new(fixed)
    marginal = Money.new(marginal) if marginal
    path = nil
    discount = (options[:code] && PricingDesc.convert_pricecode(options[:code])) || 0.2
    if postfix = options[:postfix]
      if postfix.blank?
        name = technique
        path = [technique]
      else
        name = "#{technique} - #{postfix}"
      end
    else
      name = "#{technique} @ #{fixed}"
      name += "/#{marginal}" if marginal
      name += " (#{discount})" unless discount == 0.2
    end
    path = [technique, name] unless path
    return path if @decoration_set.include?(path)

    tech = DecorationTechnique.find_by_name(path.first)
    raise "Unknown Technique: #{path.first}" unless tech
    path[1..-1].each do |p|
      unless t = tech.children.find_by_name(p)
        raise "Unknown Technique: #{path}" if p != path.last
        tech = tech.children.create(:name => name, :unit_name => tech.unit_name,
                                    :unit_default => tech.unit_default)
      else
        tech = t
      end
    end
    
    node = DecorationTechnique
    tech = nil
    path.each do |p|
      unless tech = node.find_by_name(p)
        raise "Unknown Technique: #{path}" if path.length == 1 or p != path.last
        tech = node.children.create(:name => name, :unit_name => tech.unit_name,
                                    :unit_default => tech.unit_default)
      end
      node = tech.children
    end

    unless tech.price_groups.where(:supplier_id => @supplier_record.id).first
      DecorationTechnique.transaction do
        price_group = tech.price_groups.create(:supplier => @supplier_record)
        price_group.entries.create(:minimum => 1,
                                   :fixed_price_const => 0.0,
                                   :fixed_price_exp => 0.0,
                                   :fixed_price_marginal => Money.new(0),
                                   :fixed_price_fixed => fixed,
                                   :fixed => PriceGroup.create_prices([
                                   {  :fixed => (fixed*(1.0 - discount)).round_cents,
                                      :marginal => Money.new(0), :minimum => 1 }]),
                                   :marginal_price_const => 0.0,
                                   :marginal_price_exp => 0.0,
                                   :marginal_price_marginal => marginal || Money.new(0),
                                   :marginal_price_fixed => fixed,
                                   :marginal => PriceGroup.create_prices([
                                   {  :fixed => (fixed*(1.0 - discount)).round_cents,
                                      :marginal => marginal ? (marginal*(1.0-discount)).round_cents : Money.new(0), :minimum => 1 }]),
                                   )

        DecorationDesc.techniques[path] = tech
      end
    end
    @decoration_set << path
    path
  end

  @@decoration_with_units = %w(Screen\ Print Pad\ Print)
  def decorations_from_parts(combos, techniques = [], options = {})
    decorations = [DecorationDesc.none]
    combos = combos.collect { |list| l = list.compact; l.empty? ? nil : l }.compact
    return decorations if combos.empty?
    techniques = (techniques + combos.flatten.collect { |e| e[:technique] }).flatten.compact.uniq
    techniques << "Screen Print" if techniques.empty?
    techniques.each do |tech|
      if options[:minimal]
        subs = combos.collect do |set|
          r = set.find_all { |l| l[:technique] == tech }
          r = set.find_all { |l| l[:technique].nil? } if r.empty?
          r.empty? ? [{}] : r
        end
      else
        subs = combos.collect do |set|
          r = set.find_all { |l| l[:technique].nil? || l[:technique] == tech }
          r.empty? ? [{}] : r
        end
      end
      
      def decend(hash, subs, tech)
        if subs.empty? or
            (subs.length == 1 && hash[:fixed] && !@@decoration_with_units.include?(tech))
          if method = hash.delete(:method)
            hash.merge!(:technique => [tech, method])
          else
            return unless fixed = hash.delete(:fixed)
            marginal = hash.delete(:marginal)
            dec = get_decoration(tech, fixed, marginal)
            hash.merge!(:technique => dec)
            hash = { :limit => 6 }.merge(hash) if marginal
          end
          puts "  Dec: #{hash.inspect}"
          return unless hash[:location]
          DecorationDesc.new({ :limit => 1 }.merge(hash))
        else
          subs.first.collect do |sub|
            decend(sub.merge(hash), subs[1..-1], tech)
          end
        end
      end
      
#      puts "Tech: #{tech}: #{subs.inspect}"
      decorations += decend({}, subs, tech).flatten.compact
    end
    decorations
  end
end
