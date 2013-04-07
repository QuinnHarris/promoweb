# -*- coding: utf-8 -*-

# insert into decoration_techniques (name, parent_id) values ('4 Color Photographic Paper Insert', 12);

class ETSExpressWeb < GenericImport 
  def initialize
    @product_names = Set.new
    super "ETS Express Inc"
  end

  def imprint_colors
  end

  def process_root
    fetch = WebFetch.new('http://www.etsexpress.com/')
    doc = Nokogiri::HTML(open(fetch.get_path))

    doc.xpath("//div[@class='menu']/ul/li[2]/ul/li/a").each do |a|
      process_category([a.text.strip], a.attributes['href'].value)
    end
  end

  @@product_id_regex = /\w?\d+\w?(?:_TL\d{2})?/
  @@product_url_regex = /^\/?product_detail\.php\?id=(#{@@product_id_regex})$/

  def process_category(path, href)
    puts "Category: #{path.join(', ')} : #{href}"
    begin
      fetch = WebFetch.new("http://www.etsexpress.com/#{href}")
    rescue URI::InvalidURIError => e
      puts "Invalid URI: #{e}"
      return
    end
    doc = Nokogiri::HTML(open(fetch.get_path))

    doc.xpath("//table[@id='pattern_box']/tr/td/a").each do |a|
      href = a.attributes['href'].value
      if @@product_url_regex =~ href
        process_product(path, href, $1)
      else
        process_category(path + [a.text.strip], href)
      end
    end
  end

  def process_product(path, href, product_id)
    fetch = WebFetch.new("http://www.etsexpress.com/#{href}")
    doc = Nokogiri::HTML(open(fetch.get_path))
    
    title = doc.xpath("//h1/text()[1]").text

    unless /^(?<name>.+?)\s-\s(?<color_name>.+?)\s:\s$/ =~ title
      raise "Unknown Name: #{href} - #{title.inspect}"
    end

#    if @product_names.include?(name)
#      puts "Skipped Variant: #{name} - #{color_name}"
#      return
#    end

    @product_names << name
    puts "Product: #{href} - #{name}"


    attributes = doc.xpath("/html/body/div[1]/div[3]/table[1]/tbody/tr[1]/td[2]/table/tbody/tr").each_with_object({}) do |tr, hash|
      key, blank, value = tr.xpath("td")
      next unless value
      if value.children.length == 1
        hash[key.text.strip] = value.text.strip
      elsif value.children.length == 2
        hash[key.text.strip] = value.children[0].text.strip
        rause "Duplicate tail" if hash['tail']
        hash['tail'] = value.children[1].text.strip
      else
        raise "Unknown Value: #{value}"
      end
    end

    # Ignore these attributes
#    attributes.delete('item number')
#    attributes.delete('2013 Q1 page')
#    attributes.delete('color')
#    attributes.delete('close PMS match')


    area_list = []
    if area_string = attributes.delete('imprint area (H x W x Wrap")')
      area_string.split(/[;,]/).each do |area|
        unless /^(?:([a-z]*?)\s)?([0-9\-\/x\s]+)(?:\s(\w*))?$/i =~ area.strip
          warning 'Unknown Area', area
          next
        end
        location = $1 || $3
        dim = parse_dimension($2)
        unless dim
          warning 'Unknown Dimension', area
          next
        end
        area_list << { :height => dim[:height], :width => dim[:width], :location => location || '' }
        area_list << { :height => dim[:height], :width => dim[:length], :location => "#{location} Wrap".strip } if dim[:length]
      end
    else
      warning 'No Imprint Area'
    end

    
    ProductDesc.apply(self) do |pd|
      pd.supplier_num = product_id.to_s


      # Variants
      has_lid_color = nil
      variant_map = doc.xpath("//table/tr/td/div[@id='pattern_box']/a").each_with_object({}) do |a, hash|
        unless @@product_url_regex =~ a.attributes['href'].value
          raise "Unknown URL: #{a.attributes['href'].value.inspect}"
        end
        id = $1
        
        list = a.xpath("text()")
        color = list.shift.text.strip

        puts "Color: #{id} => #{color}"
        if id[0] == 'K' # K represents clear with different lid color?
          hash[id] = { 'color' => 'clear', 'lid color' => color }
          has_lid_color = true
        else
          hash[id] = { 'color' => color }
        end

        product_str = list.shift.text.strip
        unless /^\#(#{@@product_id_regex})$/ =~ product_str
          raise "Unknown Product ID: #{product_str}"
        end
        if list.length == 1
          next unless id == pd.supplier_num # only if this is the product.  Tags will be merged?
          case list.last.text.strip
          when 'on sale'
            pd.tags << 'Special'
          when /^clearance prices/, 'while supplies last'
            pd.tags << 'Closeout'
          when /^available/ # Handle this
          else
            raise "Unknown list entry #{href}: #{list.last.text.strip}"
          end
        elsif !list.empty?
          raise "Unknown list length: #{list.inspect}"
        end
      end

      variant_map.each { |k, prop| k[0] == 'K' || (prop['lid color'] = prop['color']) } if has_lid_color
      
      if variant_map.empty?
        variant_map[product_id] = { 'color' => color_name }
      else
        # Remove duplicate property groups and apply latter common groups as individual products
        puts "MAP: #{variant_map.inspect}"
        duplicate_color_ids = variant_map.group_by { |k, v| v }.collect { |v, list| list.length > 1 ? list.collect { |k, v| k } : nil }.compact.flatten
        puts "DUP: #{duplicate_color_ids.inspect}"
        unless duplicate_color_ids.empty?
          duplicate_color_ids = duplicate_color_ids[1..-1]
          if duplicate_color_ids.include?(pd.supplier_num)
            variant_map.select! { |k, v| k == pd.supplier_num }
          else
            variant_map.select! { |k, v| !duplicate_color_ids.include?(k) }
          end
        end

        raise "ID not listed #{href}" unless variant_map[product_id]
        pd.supplier_num = variant_map.keys.sort.first # Use lowest sort product id
      end

      pd.name = name
      pd.description = [attributes.delete('description'), attributes.delete('dishwasher info'), attributes.delete('microwave info')]
      pd.supplier_categories = [path]

      pd.package.units = attributes.delete('case pack').to_i
      pd.package.weight = attributes.delete('case weight (lbs.)')
      dim_string = attributes.delete('case dimensions (L x W x D")')
      if dim = parse_dimension(dim_string)
        pd.package.merge!(dim)
      else
        warning "Unknown case dimensions", dim_string
      end

      pd.tags << 'Closeout' if attributes['tail'].to_s.include?('clearance')

     
      height = parse_number(attributes['item height']) if attributes['item height']
      diameter = parse_number(attributes['item diameter']) if attributes['item diameter']
      if height and diameter
        pd.properties['dimension'] = { :height => height, :diameter => diameter }
      else
        list = []
        list << "Height: #{attributes['item height']}" if attributes['item height']
        list << "Diameter: #{attributes['item height']}" if attributes['item diameter']
        pd.properties['dimension'] = list.join(', ')
      end
      attributes.delete('item height'); attributes.delete('item diameter')
      
      
      attributes.each do |attr, value|
        warning "Unused attribute", attr
      end


      pd.lead_time.normal_min = 5
      pd.lead_time.normal_max = 10
      pd.lead_time.rush = 1
      pd.lead_time.rush_charge = 1.25


      # Pricing
      pricing_table = doc.xpath("//table[@class='pricing-wrapper']/tr[@class='us-pricing']/td/table").last
      qty_max = nil
      qty_list = pricing_table.xpath('tbody/tr/td/div/strong').collect do |s| 
        a, b = s.text.split('-')
        if b
          raise "Multiple max" if qty_max
          qty_max = Integer(b)
        end
        Integer(a)
      end
      price_hash = pricing_table.xpath('tbody/tr[position() > 1]').each_with_object({}) do |tr, hash|
        begin
          hash[tr.xpath('td[1]').text.strip] = tr.xpath('td/div').collect { |s| %w(- n/a).include?(s.text) ? nil : Money.new(Float(s.text)) }
        rescue ArgumentError
          warning "Bad Price Argument", tr.to_s
        end
      end

#      pd.decorations = [DecorationDesc.none]

      price_technique = nil
      case price_hash.first.first
      when /^1 color imprint \(c\)/
        price_technique = 'Screen Print'
        technique_limit = 4
      when /^4 color process paper insert/
        price_technique = ['4 Color Photographic', '4 Color Photographic Paper Insert']
        technique_limit = 1
      else
        warning "First Row is not price", price_hash.first.first
      end

      if price_technique
        price_list = price_hash.delete(price_hash.first.first)
        raise "Mismatch list" unless qty_list.length == price_list.length
        qty_list.zip(price_list).each do |qty, price|
          next unless price
          pd.pricing.add(qty, price, 'c')
        end
        pd.pricing.maxqty(qty_max)
        pd.pricing.ltm(50.0)

        area_list = [{:location => ''}] if area_list.empty?
        puts "DEC: #{price_technique.inspect} #{area_list.inspect}"
        pd.decorations = area_list.collect { |area| DecorationDesc.new({ :technique => price_technique, :limit => technique_limit }.merge(area)) }
        puts "DECC: #{pd.decorations.inspect}"
      end

      price_hash.each { |key, list| warning 'Unknown Price Item', key }

      # Group Image
      if group_node = doc.at_xpath("//table/tbody/tr/td/a") and group_node.attributes['href']
        group_url = group_node.attributes['href'].value
        pd.images = [ImageNodeFetch.new(group_url.split('/').last, group_url, 'group')] if /\.jpg$/ =~ group_url
     end

      pd.variants = variant_map.collect do |variant_id, prop|
        vd = VariantDesc.new(:supplier_num => variant_id)
        vd.properties = prop

        # Download HiRes from FTP
        if images = @image_list[variant_id]
          vd.images = images.collect do |image|
            ImageNodeFetch.new(image[0], image[1], image[2])
          end
        end
        # If not availible download from website
        if vd.images.blank?
          vd.images = [ImageNodeFetch.new("#{variant_id}s", "http://www.etsexpress.com/sjpeg/#{variant_id}s.jpg")]
        end

        vd
      end
    end

    
  end


  def parse_products
    @image_list = get_ftp_images({ :server => '174.34.88.59',
                                   :login => 'ETSFTP1', :password => 'bolt' },
                                 ['Download/Images_High-Res_Blank',
                                  'Download/Images_High-Res_Logos']) do |path, file|
      if /^((#{@@product_id_regex})(.*?))\.jpg$/ === file
        blank = path.include?('Blank')
        [(blank ? 'B-' : 'L-') + $1, $2, $2, (blank ? 'blank' : nil)]
      end
    end

    process_root
  end
end
