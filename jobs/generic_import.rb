require 'rubygems'
require 'RMagick'
require File.dirname(__FILE__) + '/../config/environment'
require 'open-uri'
require File.dirname(__FILE__) + '/progressbar'
require File.dirname(__FILE__) + '/categories'

JOBS_DATA_ROOT = RAILS_ROOT + "/jobs/data"

class XLSFile
  def initialize(file)
    book = Spreadsheet.open(file)
    @worksheet = book.worksheet(0)
    @header = @worksheet.row(0).collect do |cell|
      cell.to_s.downcase
    end
  end
  
  attr_reader :worksheet
  
  def get(row, name)
    raise "Unknown Header: #{name}" unless i = @header.index(name.downcase)
    row.at(i)
  end
end


class ImageNode
  @@cache_dir = File.join(RAILS_ROOT, "cache")

  def initialize(id)
    @id = id
  end 

  attr_reader :id

  def ==(other)
    @id == other.id
  end

  def to_s; id; end
end

class ImageNodeFetch < ImageNode
  def initialize(id, uri)
    super id
    @uri = URI.parse(uri.gsub(' ', '%20'))
  end

  attr_reader :uri

  def uri_tail
    @uri.respond_to?(:request_uri) ? @uri.request_uri : @uri.path
  end

  def path
    base = "#{@@cache_dir}/#{@uri.host}/#{uri_tail}"
    base = "#{base}/index.html" if @uri.path[-1..-1] == '/'
    base
  end

  def get
    puts "GET: #{uri}"
   unless File.exists?(path)
      FileUtils.mkdir_p(File.split(path).first)

      begin
        puts "Fetch: #{@uri}"
        pbar = nil
        @uri.open(:content_length_proc => lambda {|t|
                    if t && 0 < t
                      name = /\/(\w+)(?:\.(\w+))?$/ =~ uri_tail ? $1 : uri_tail
                      pbar = ProgressBar.new(name, t)
                      pbar.file_transfer_mode
                    end },
                  :progress_proc => lambda {|s|
                    pbar.set s if pbar
                  }) do |f|
          return nil if f.length == 0
          File.open(path, 'w') { |file| file.write(f.read) }
        end
        puts
        return path
      rescue OpenURI::HTTPError, URI::InvalidURIError, Errno::ETIMEDOUT => e
        puts " * #{e.class} : #{@uri}"
        return nil
      end
    end

    return File.open(path)
  end
end

class LocalFetch
  def initialize(path, filename)
    @filename = filename
    @path = File.join(path, filename)
  end

  attr_reader :path, :filename
#  def get_path; @path; end

  def apply_image(type, record)
    return true if record.image_exists?(type)
    return nil unless @path
    record.image_copy(path, type)
    return true
  end
end

class WebFetch
  @@cache_dir = File.join(RAILS_ROOT, "cache")
  
  def initialize(uri)
    @uri = URI.parse(uri.gsub(' ', '%20'))
  end
  
  attr_reader :uri
  
  def ==(other)
    @uri == other.uri
  end

  def uri_tail
    @uri.respond_to?(:request_uri) ? @uri.request_uri : @uri.path
  end

  def path
    base = "#{@@cache_dir}/#{@uri.host}/#{uri_tail}"
    base = "#{base}/index.html" if @uri.path[-1..-1] == '/'
    base
  end
  
  def filename
    path.split('/').last
  end
  
  def get_path(time = nil)
    begin
      stat = File.stat(path)
      if stat.file? and
         (!time or stat.mtime > time)
        return path
      end
    rescue Errno::ENOENT

    end

    FileUtils.mkdir_p(File.split(path).first)

    begin
      puts "Fetch: #{@uri}"
      pbar = nil
      @uri.open(:content_length_proc => lambda {|t|
        if t && 0 < t
          name = /\/(\w+)(?:\.(\w+))?$/ =~ uri_tail ? $1 : uri_tail
          pbar = ProgressBar.new(name, t)
          pbar.file_transfer_mode
        end },
      :progress_proc => lambda {|s|
        pbar.set s if pbar
      }) do |f|
        return nil if f.length == 0
        File.open(path, 'w') { |file| file.write(f.read) }
      end
      puts
      return path
    rescue OpenURI::HTTPError, URI::InvalidURIError, Errno::ETIMEDOUT => e
      puts " * #{e.class} : #{@uri}"
      nil
    end
  end 
end

class GenericImageFetch < WebFetch

end

class CopyImageFetch < GenericImageFetch
  def apply_image(type, record)
    return true if record.image_exists?(type)
    return nil unless path = get_path
#    record.image_import(path, type)
    record.image_copy(path, type)
    return true
  end
end

class TransformImageFetch < GenericImageFetch 
  def apply_image(type, record)
    return true if record.image_exists?(type)
    return nil unless path = get_path
    record.image_transform(path, type)
    return true
  end
end

class HiResImageFetch < GenericImageFetch 
  def apply_image(type, record)
    return true if record.image_exists?('thumb')
    if path = get_path
      if hires = record.image_convert(path, 'hires')
        hires.strip!
        %w(thumb main large).each do |name|
          record.image_transform(hires, name)
        end
      end
      return true
    end
    return nil
  end
end

class GenericImport
  @@properties = %w(material color dimension fill container pieces shape size memory)

  @@cache_dir = File.join(RAILS_ROOT, "jobs/cache")
  
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
    @invalid_prods = []
  end
  
  def get_id(supplier_num)
    product_record = @supplier_record.get_product(supplier_num)
    if product_record.new_record?
      product_record = @supplier_record.get_product(supplier_num)
      product_record.name = ''
      product_record.deleted = true
      product_record.save!
      puts "Allocating #{supplier_num} => #{product_record.id}"
    end
    product_record.id
  end
  
  def run_parse
    init_time = Time.now
    puts "#{@supplier_record.name} parse start at #{init_time}"
    @product_list = []
    parse_products
    stop_time = Time.now
    puts "#{@supplier_record.name} parse stop at #{stop_time} for #{stop_time - init_time}s" 
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
    puts "#{file_name} reading cached marshal"
    File.open(file_name) { |f| Marshal.load(f) }    
  end
  
  def cache_write(file_name, res)
    File.open(file_name,"w") { |f| Marshal.dump(res, f) }
  end
  
  def cache_marshal(name, predicate = nil)
    file_name = cache_file(name)
    if cache_exists(file_name)
      unless predicate and File.mtime(predicate) > File.mtime(file_name)
        return cache_read(file_name)
      end
    end

    res = yield
    cache_write(file_name, res)
    res
  end
  
  def run_parse_cache
    @product_list = cache_marshal("#{@supplier_record.name}_parse", @src_file) do
      run_parse
      @product_list
    end  
  end
  
#  def run_validate
#    puts "#{@supplier_record.name} validate start <<<<<<<<<<<<<<<"
##    @product_list.each { |prod| validate_product(prod) }
#    @invalid_prods = []    
#    @product_list.delete_if do |product|
#      begin
#        validate_product(product)
#        next nil
#      rescue => boom
#        puts "Validate Error: #{product['supplier_num']} (Not Included)"
#        puts boom
#        puts boom.backtrace
#        @invalid_prods << product['supplier_num']
#        next true
#      end
#    end
#    puts "#{@supplier_record.name} validate stop >>>>>>>>>>>>>>>>>"
#  end
  
private
  def run_cleanup(product_ids)
    database = @supplier_record.products.collect do |p|
      @invalid_prods.index(p.supplier_num) ? nil : p.id
    end.compact
    puts "#{database.size} - #{product_ids.size}"
    (database - product_ids).collect do |product_id|
      product_record = Product.find(product_id)
      puts " Deleted Product: #{product_record['supplier_num']} (#{product_record.id})"
      product_record.delete
      product_record
    end  
  end
  
public 
  def run_apply(cleanup = true)
    product_ids = @product_list.collect { |prod| apply_product(prod).id }
    run_cleanup(product_ids) if cleanup
    self.class.write_ids
  end
  
  def run_transform
    trans = NewCategoryTransform.new [@supplier_name].flatten.first
    @product_list.each do |prod|
      trans.apply_rules(prod)
    end
  end
  
  def run_apply_cache(cleanup = true)
    file_name = File.join(@@cache_dir,"#{@supplier_record.name}_database")
    last_data = {}
    last_ids = {}
    begin
      if File.ftype(file_name) == "file"
        puts "#{@supplier_record.name} reading apply cached marshal"
        last_data, last_ids = File.open(file_name) { |f| Marshal.load(f) }
      end
    rescue
    end
    
    product_ids = @product_list.collect do |prod|
      num = prod['supplier_num']
      if last_data[num] != prod
        if rec = apply_product(prod) 
          last_ids[num] = rec.id
          last_data[num] = prod
        end
      end
      last_ids[num]
    end
    
    run_cleanup(product_ids).each do |product_record|
      last_ids.delete(product_record.supplier_num)
      last_data.delete(product_record.supplier_num)
    end if cleanup
    
    File.open(file_name,"w") { |f| Marshal.dump([last_data, last_ids], f) }
  end
  
  # For debuging
  def run_apply_for_product(num)
    @product_list.each do |prod|
      next unless prod['supplier_num'] == num
      apply_product(prod)
    end
  end
  
  def add_product(product_data)
    begin
      validate_product(product_data)
      @product_list << product_data
    rescue => boom
      puts "Validate Error: #{product_data['supplier_num']} (Not Included)"
      puts boom
      puts boom.backtrace
      @invalid_prods << product_data['supplier_num']
    end
  end
  
  def each_product
    @product_list.each { |p| yield p }
  end
  
  def validate_product(product_data) 
    product_log = ''
    
    # check presense
    %w(supplier_num name description decorations supplier_categories variants).each do |name|
      if product_data[name].nil?
        raise "Value #{name} is nil"
      end
    end
    
    raise "Must have at least one variant" if product_data['variants'].empty?
    
    # check all variants have the same set of properties
    prop_list = @@properties.find_all { |p| product_data['variants'].find { |v| v[p] } }
    prop_list += product_data['variants'].collect { |v| v['properties'] && v['properties'].keys }.flatten.compact
    prop_list.each do |prop_name|
      product_data['variants'].each do |variant|
        unless variant[prop_name] or variant['properties'][prop_name]
          raise "Variant \"#{variant['supplier_num']}\" doesn't have property \"#{prop_name}\" unlike [#{(product_data['variants'].collect { |v| v['supplier_num'] } - [variant['supplier_num']]).join(',')}]"
        end
      end
    end

    # check unique variant supplier_num
    raise "Variant supplier_num not unique" unless product_data['variants'].collect { |v| v['supplier_num'] }.uniq.length == product_data['variants'].length
  
    # check technique
    product_data['decorations'] = product_data['decorations'].collect do |decoration|
      unless @decoration_techniques[decoration['technique']]
#        product_log << "  Unknown Decoration Technique: #{decoration.inspect}\n"
        nil
      else
        decoration
      end
    end.compact
    
    # check categories
    if product_data['supplier_categories'].empty?
      product_log << "Unclassified" 
    else
      raise "Category not list" unless product_data['supplier_categories'].is_a?(Array)
      product_data['supplier_categories'].each do |category|
        raise "Subcat not list" unless category.is_a?(Array)
        category.each { |str| raise "Cat not string: #{product_data['supplier_categories'].inspect}" unless str.is_a?(String)}
      end
    end
    
    # check images
    if (product_data['variants'].collect { |v| v['images'] } + [product_data['images']]).flatten.compact.empty?
      unless product_data["image-hires"] or product_data["images"]
        %w(thumb main large).each do |name|
          product_log << "  No #{name} image" unless product_data["image-#{name}"]
        end
      end
    end
    
    # check prices
    product_data['variants'].each do |variant|
      %w(costs prices).each do |type|
        minimum = nil
        marginal = nil
        raise "No #{type}" unless variant[type] and !variant[type].empty?
        raise "Duplicate #{type}: #{variant[type].inspect}" unless variant[type].length == variant[type].uniq.length
        variant[type].each do |price|
          raise "Minimum is null value: #{variant[type].inspect}" unless price[:minimum]
          raise "Minimum not sequential for #{type}: #{variant[type].inspect}" if minimum and price[:minimum] <= minimum
          raise "Null marginal not last item: #{variant[type].inspect}" if minimum and !marginal
          raise "Marginal not sequential for #{type}: #{variant[type].inspect}" if marginal and price[:marginal] and price[:marginal] > marginal
          minimum = price[:minimum]
          marginal = price[:marginal]
        end
      end
    end

#    costs, prices = product_data['variants'].collect { |v| [v['costs'], v['prices']] }.transpose
#    raise "Must have matching number of cost and price groups: #{costs.uniq.length} != #{prices.uniq.length}" if costs.uniq.length != prices.uniq.length
    
    # check images
#    unless product_data["image-hires"] and product_data["image-hires"].get_path
#      %w(thumb main).each do |name|
#        unless product_data["image-#{name}"].get_path
#          raise "Image not found"
#        end
#      end
#    end
    
    unless product_log.empty?
      puts " Product: #{product_data['supplier_num']}\n" + product_log
    end
  end
    
  def apply_product(product_data)
    product_log = ''
    product_new = nil
        
    product_record = @supplier_record.get_product(product_data['supplier_num'])
        
    begin     
      Product.transaction do
        unless product_new = product_record.new_record?
          if product_record.deleted
            if product_record.variants.empty?
              puts " Using Allocated #{product_record.id}"
            else
              puts " Recovering #{product_record.id}"
            end

            product_record.deleted = false
            product_new = true
          end
        end
        
        # Set Product record properties
        %w(name description
           package_weight package_units package_unit_weight
           package_height package_width package_length data
           lead_time_normal_min lead_time_normal_max lead_time_rush lead_time_rush_charge).each do |attr_name|
          if product_record[attr_name] != product_data[attr_name]
            product_log << "  #{attr_name}: #{product_record[attr_name].inspect} => #{product_data[attr_name].inspect}\n"
            product_record[attr_name] = product_data[attr_name]
          end
        end
        
        product_record.save! #if changed or product_new

       # Fetch images (Remove for next)
        %w(thumb main large hires).each do |name|
          if product_data["image-#{name}"]
            unless product_data["image-#{name}"].apply_image(name, product_record)
              puts "  *** Failed with no image"
              return nil
            end
          end
        end
        
        decorations = product_data['decorations'].collect do |decoration|
          decoration.merge({ 'technique' => @decoration_techniques[decoration['technique']]})
        end
        
        product_log << product_record.set_decorations(decorations)
        product_log << product_record.set_categories(product_data['categories'].collect { |a| a.collect { |b| b[0...32] } })
        product_log << product_record.set_tags(product_data['tags'] || [])
        
        new_price_groups, new_cost_groups = [], []

        # Fetch Images
        product_record.set_images(product_data['images'])
       
        # Process Variants
        variant_records = product_data['variants'].collect do |variant_data|
          variant_log = ''
          variant_record = product_record.get_variant(variant_data['supplier_num'])
          variant_new = variant_record.new_record?
          variant_record.save! if variant_new

          # Fetch Images
          variant_record.set_images(variant_data['images'])
          
          # Properties
          @@properties.each do |attr_name|
            next unless value = variant_data[attr_name]
            value = value.collect { |k, v| "#{k}:#{v}" }.sort.join(',') if value.is_a?(Hash)
          
            variant_record.set_property(attr_name, value, variant_log)
          end

          variant_data['properties'].each do |name, value|
            value = value.collect { |k, v| "#{k}:#{v}" }.sort.join(',') if value.is_a?(Hash)
            variant_record.set_property(name, value, variant_log)
          end if variant_data['properties']
  
          if variant_data["swatch-medium"]  
            swatch_prop = variant_record.set_property('swatch', variant_data["swatch-medium"].filename, variant_log)
            
            # Fetch images
            %w(small medium).each do |name|
              variant_data["swatch-#{name}"].apply_image(name, swatch_prop) if variant_data["swatch-#{name}"]
            end
          end
          
          # Match groups to variant list.  Ensure cost and price lists match
          if pg = new_price_groups.zip(new_cost_groups).find do |(dp, vp), (dc, vc)|
              dp == variant_data['prices'] and dc == variant_data['costs']
            end
            pg[0][1] << variant_record
            pg[1][1] << variant_record
          else
            new_price_groups << [variant_data['prices'], [variant_record]]
            new_cost_groups << [variant_data['costs'], [variant_record]]
          end

#          [[new_price_groups, 'prices'], [new_cost_groups, 'costs']].each do |group, name|
#            if g = group.find { |brks, variants| brks == variant_data[name] }
#              g[1] << variant_record
#            else
#              group << [variant_data[name], [variant_record]]
#            end
#          end
                    
          # Log it
          if variant_new
            product_log << "  Variant: #{variant_data['supplier_num']} (NEW)\n"
          elsif !variant_log.empty?
            product_log << "  Variant: #{variant_data['supplier_num']}\n"
            product_log << variant_log
            variant_record.save! # Update updated_at
          end
          
          variant_record
        end
        
        # Remove variants
        (product_record.variants - variant_records).each do |variant_record|
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

        recache_prices = product_new

        [[new_price_groups, @supplier_record.price_source],
         [new_cost_groups, nil]].each do |dst, source_id|
          log = product_record.set_prices(source_id, dst)
          recache_prices = true unless log.empty?
          product_log += log
        end

        # Check shit
        product_record.variants.each do |variant|
          srcs = variant.price_groups.collect { |g| g.source }
          unless srcs.length == srcs.uniq.length
            puts "#{variant.id}: #{variant.price_groups.inspect}"
            raise "Multiple price groups from the same source" 
          end
        end
        
        if recache_prices
          pc = PriceCollectionCompetition.new(product_record)
          pc.calculate_price
        end

        product_record.variants.target = variant_records
      end
    rescue Exception
      puts product_data.inspect
      raise
    ensure
      # Log it
      if product_new
        puts " Product: #{product_data['supplier_num']} (#{product_record.id}) (NEW)"
      elsif !product_log.empty?
        puts " Product: #{product_data['supplier_num']} (#{product_record.id})\n" + product_log
        product_record.updated_at_will_change!
        product_record.save! # Update updated_at
      end
    end
    
    product_record
  end
  
  
private
  @@hw_reg  = /^(?:([a-z ]+)[:;]? *)?(\d{1,2}(?:\.\d{1,2})?[^\/])?(?:(\d{1,2})\/(\d{1,2}))? ?"? ?w? +x +(\d{1,2}(?:\.\d{1,2})?[^\/])?(?:(\d{1,2})\/(\d{1,2}))? ?"? ?h?\.? ?([a-z]*)$/i
  @@single_reg = /^(?:([a-z ]+)[:;]? *)?(\d{1,2}(?:\.\d{1,2})?[ "])?(?:(\d{1,2})\/(\d{1,2}))? ?"? *([^0-9]*)/i

  def parse_area(str)
    all, pre, w_a, w_n, w_d, h_a, h_n, h_d, post = @@hw_reg.match(str).to_a
    if all
      width = w_a ? w_a.to_f : 0.0
      width += w_d ? w_n.to_f / w_d.to_f : 0.0
      height = h_a ? h_a.to_f : 0.0
      height += h_d ? h_n.to_f / h_d.to_f : 0.0
      { 'width' => width, 'height' => height }
    else
      all, pre, a, n, d, post = @@single_reg.match(str).to_a
      post.downcase!
      val = (a ? a.to_f : 0.0) + (d ? (n.to_f/d.to_f) : 0.0)
      if all
        case post
          when /^ *sq/
            { 'width' => val, 'height' => val }
          when /^ *dia/
            { 'diameter' => val }
          when /^ *equilateral triangle/
            { 'triangle' => val }
          else
            nil
        end
      else
        nil
      end
    end  
  end

  def parse_area2(string)
    if /^(?:(\d{1,2})[- ])?(\d{1,2})(?:\/(\d{1,2}))?\"\s*(H|W)\s*x?\s*(?:(\d{1,2})[- ])?(\d{1,2})(?:\/(\d{1,2}))?\"\s*(W|H)\s*$/i === string
      if $4 == $8
        puts "Duplicate #{$4}"
        return nil
      end
      return {
        (($4.upcase == 'H') ? 'height' : 'width') => $1.to_f + $2.to_f / ($3 || 1).to_f,
        (($8.upcase == 'H') ? 'height' : 'width') => $5.to_f + $6.to_f / ($7 || 1).to_f
      }
    end

    if /^(?:(\d{1,2})[- ])?(\d{1,2})(?:\/(\d{1,2}))?\"\s*dia/i === string
      return { 'diameter' => $1.to_f + $2.to_f / ($3 || 1).to_f }
    end

    nil
  end
  
  @@volume_reg = /^ *(\d{1,2}(?:\.\d{1,2})?[ -]?)?(?:(\d{1,2})\/(\d{1,2}))? ?"? ?([lwhd])?/i
  def parse_volume(str)
    res = {}
    list = %w(l w h)
    str.split('x').collect do |comp|
      all, a, n, d, dim = @@volume_reg.match(comp).to_a
      dim = list.shift if res.has_key?(dim) or !dim
#      return nil if res.has_key?(dim)
      res[dim] = (a ? a.to_f : 0.0) + (d ? (n.to_f/d.to_f) : 0.0)
      list.delete_if { |x| x == dim }
    end
#    return nil unless res.size == 3
    res
  end

  def convert_pricecode(comp)
    comp = comp.upcase[0] if comp.is_a?(String)
    num = nil
    num = comp - ?A if comp >= ?A and comp <= ?G
    num = comp - ?P if comp >= ?P and comp <= ?X
    
    raise "Unknown PriceCode: #{comp}" unless num
    
    0.5 - (0.05 * num)
  end
  
  def convert_pricecodes(str)
    count = 1
    str.strip.upcase.unpack("C*").collect do |comp|
      if comp > ?0 and comp <= ?9
        count = comp - ?0
        next nil
      end
      
      begin
        num = convert_pricecode(comp)
        ret = (0...count).collect { num }
        count = 1
        next ret
      rescue
        raise "Unknown PriceCodes: \"#{str}\""
      end
    end.compact.flatten
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
end
