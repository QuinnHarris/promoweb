# -*- coding: utf-8 -*-
class PrimeLineWeb < GenericImport
  @@decoration_replace = {
    'Silk Screened' => 'Screen Print',
    'Silk Screnned' => 'Screen Print',
    'silk screened' => 'Screen Print',
    "Silk screened" => 'Screen Print',
    "Silk Screened via PermaPrime" => 'Screen Print',
    'Pad Printed' => 'Pad Print',
    'Pad Print' => 'Pad Print',
    'Pad Printing' => 'Pad Print',
    "Pad Printed." => 'Pad Print',
    "pad printed" => 'Pad Print',
    "Pad printed" => 'Pad Print',
    "Image Bonding" => 'Image Bond',
    "Image Bonding\303\242\204\242" => 'Image Bond',
    "Image Bonding\303\242\204\242. " => 'Image Bond',
    "Image Bonding\256" => 'Image Bond',
    "Image Bonding on black case" => 'Image Bond',
    "Laser Engraved. Please note: Laser Engraving color may vary." => 'Laser Engrave',
    "Laser Engraved only. Please note: Laser Engraving color may vary." => 'Laser Engrave',
    "Laser Engraved with oxidation. Please note: Laser Engraving color may vary." => 'Laser Engrave',
    "Laser engraved. Please note: Laser Engraving color may vary." => 'Laser Engrave',
    "Laser Engraved" => 'Laser Engrave'
    
  }
  
  @@decoration_modifiers = {
    'up to 4 colors' => 4,
    'up to 4 colors.' => 4,
    'one color only' => 1,
    '1 color only' => 1,
  }
  
  @@upcases = %w(AM FM MB GB USB)
  
  
  def initialize
    super "Prime Line"
  end

  def imprint_colors
    %w(Yellow 116 1235 021 1787 199 202 208 225 267 2925 287 281 Process\ Blue Reflex\ Blue 327 Green 347 343 4635 423 877 873 Black White)
  end

  @@display = 256

  def process_root
    fetch = WebFetch.new('http://www.primeline.com/')
    doc = Nokogiri::HTML(open(fetch.get_path))
    categories = {}
    doc.xpath("//a").each do |a|
      next unless a['href'].include?('/Products/ProductList.aspx')
      next if a.inner_html.include?('<img')
      url = a['href'].gsub(/^\.\.\//, '')
      categories[url] = (categories[url] || []) + [a.inner_html.encode('ASCII', :invalid => :replace, :undef => :replace, :replace => '').strip.gsub(/\s+/, ' ').gsub(/<.*?>/,'').gsub(/&.+;/, '')]
    end

    categories.each do |path, category_list|
#      puts "Category: #{category_list.inspect}"
      url = "http://www.primeline.com/#{path}&TotalDisplay=#{@@display}"
      process_category(category_list.uniq.join(' '), url)
    end
  end
  
  def products_list(name)
    fetch = WebFetch.new("http://www.primeline.com/Products/ProductList.aspx?SearchType=#{name}&TotalDisplay=#{@@display}")
    doc = Nokogiri::HTML(open(fetch.get_path))
    
    doc.xpath("//table[@id='Table4']/tr/td/div/a").to_a.collect do |a|
      next nil unless a['href'].index('ProductDetail')
      a['href'].strip.gsub(/^\.\.\//, '')
    end
  end
  
  def parse_web
    @products = cache_marshal('Prime Line_pre') do
      @tags = {}
      @product_pages = {}
      @product_pages.default = []
      products_list('New').each { |p| @tags[p] = 'New' }
      products_list('Specials').each { |p| @tags[p] = 'Special' }
      products_list('HotDeals').each { |p| @tags[p] = 'Special' }
      products_list('Closeouts').each { |p| @tags[p] = 'Closeout' }
      products_list('nonstock').each { |p| @product_pages[p] = ['Overseas'] }

      process_root

#      products_list('').each do |path|
#        unless @product_pages[path]
#          @product_pages[path] = ["UNKOWN"]
#        end
#      end
      
      puts "Processing #{@product_pages.length} products"
      @product_pages.collect do |path, categories|
        process_product(categories, "http://www.primeline.com/#{path}", @tags[path])
      end.compact
    end
  end

  def process_category(category, url)
    puts "Category: #{url}  #{category}"
    fetch = WebFetch.new(url)
    return unless path = fetch.get_path
    count = 0
    Nokogiri::HTML(open(path)).xpath("//table[@id='Table4']/tr/td/div/a").each do |a|
      next unless a['href'].index('ProductDetail')
      path = a['href'].strip.gsub(/^\.\.\//, '')
#      puts "Product: #{path} : #{category}"
      @product_pages[path] = (@product_pages[path] || []) + [category]
      count += 1
      #      process_product(category, "http://www.primeline.com/Products/#{a['href'].strip}", @tags[a['href']])
    end
    raise "Overflow" if count >= @@display
    puts "  Products: #{count}"
  end
  
  def parse_method(method, data, log)
    unless method
      log << " * No technique given"
      return nil
    end
    
    method, modifier = method.split(',')
    if modifier
      limit = @@decoration_modifiers[modifier.strip]
      if limit
        data = data.merge({ 'limit' => limit })
      else
        log << " * Unknown Modifier: #{modifier.inspect}"
        return nil
      end
    end
    
    lst = method.split(/(?: ?\/ ?)|(?: or )/)
    return lst.collect do |meth|
      meth = @@decoration_replace[meth]
      next data.merge({ 'technique' => meth }) if meth
      log << " * Couldn't parse split technique: #{method.inspect}"
      next nil
    end
  end

  private
  def iconv(str)
    Iconv.iconv('UTF-8', 'UTF-8', str).first
  end
  public

  def process_product(categories, url, tag)
    fetch = WebFetch.new(url)
    doc = Nokogiri::HTML(open(fetch.get_path), 'ASCII')
    return nil unless doc

    prod_name = iconv(doc.xpath("//span[@id='ctl00_content_ProductName']").inner_html).split(' ').collect do |c|
      @@upcases.index(c.upcase.gsub(/\d/,'')) ? c.upcase : c.capitalize
    end.join(' ')

    data = {
      'supplier_num' => doc.xpath("//span[@id='ctl00_content_ProductCode']").inner_html,
      'name' => prod_name
    }
    puts "Number: #{data['supplier_num']}"

    main_img = doc.xpath("//img[@id='ctl00_content_PIM']").first['src']
    log = []
    return nil if main_img == "Product_Images/picturesoon.jpg"
    
    note = doc.xpath("//span[@id='ctl00_content_ProductClasstext']").to_a
    return nil if note and note.first.inner_html == "Non-Stock"

    properties = []
    doc.xpath("//td[@id='ctl00_content_TableCell1']/span").each do |span|
      raise "Unkonown prop" unless /^\s*<b>\s*(.+?)\s*:\s*<\/b>\s*(.+?)$/ =~ span.inner_html
      name, value = $1.strip, iconv($2.strip)
      puts "  - #{name.inspect} : #{value.inspect}"
      properties << [name, value]
    end    
    data['properties'] = properties    
    
    # Features
    features = doc.xpath("//img[@src='images/bulletArrow.gif']").collect do |img|
      str = iconv(img.next_sibling.inner_html).gsub(/(<[^>]+>)|(<--.*)/,'').strip
      (/free shipping/i) === str ? nil : str
    end.compact
#    log << " * NO FEATURES" if features.empty?
    

    price_no_special = nil
    price_no_less = nil
    price_note = doc.xpath("//span[@id='ctl00_content_PriceNote']").to_a.join.strip
    unless price_note.empty?
      data['price_note'] = price_note
      price_note = price_note.downcase
      price_no_special = true if price_note.index('special pricing') 
      price_no_less = true if price_note.index('less than minimum')
    end
    
    setup_price = doc.xpath("//span[@id='ctl00_content_SetupCostDesc']").first.inner_html
    running_price = doc.xpath("//span[@id='ctl00_content_RunningCostDesc']").first
    running_price = running_price.inner_html if running_price
#    @decoration_costs << [setup_price ? setup_price.strip : nil, running_price ? running_price.strip : nil]
    
    variant_prices = {}
    price_codes = {}
    
    # Price Code
    price_list = (doc.xpath("//span[@id='ctl00_content_DiscountCode']") +
                  doc.xpath("//span[@id='ctl00_content_DiscountCodeCloseout']")).first
    if price_list
      price_str = price_list.inner_html.strip.gsub(/<.+>/,'')
      price_str += 'C' if price_str.length == 1 and price_str[0] > ?0 and price_str[0] <= ?9 #Kludge for 4 without C price
      price_list = price_str.empty? ? nil : convert_pricecodes(price_str)
    end
    
    price_rows = doc.xpath("//tr[@id='ctl00_content_RegularPriceRow']/td/table/tr/td") +
                 doc.xpath("//tr[@id='ctl00_content_CloseoutPriceRow']/td/table/tr/td")
    price_rows.each do |price_row|
      rows = price_row.xpath("table/tr/td/table/tr[td/font]")
      next unless rows and rows.length > 1
      
      minimums = rows.shift.xpath("//td[@align='right']/font/b").to_a.compact
      next if minimums.empty?
      minimums = minimums.collect { |m| m.inner_html.to_i }
      
      rows.each do |row|
        head = row.xpath("td/span/font").first
        head = head.inner_html.downcase if head
        
        list = row.xpath("td/font").collect { |e| e.inner_html.strip.empty? ? nil : e.inner_html }.compact
        next nil if list.empty?
        
        variant_prices[head] = minimums.zip(list).collect do |min, price|
          { :minimum => min.to_i,
            :marginal => Money.new(price[1..-1].to_f).round_cents,
            :fixed => Money.new(0) } if price and price[1..-1].to_f != 0.0
        end.compact
        price_codes[head] = price_list || (0...minimums.size).collect { 0.4 }
      end
    end

    # Lead Times
#    variant_prices.keys.find do |name|
#      if /(\d)-Day Rush/i === name
#        data['lead_time_rush'] = $1.to_i
#      end
#      if /24 hour rush/i === name
#        data['lead_time_rush'] = 1
#      end
#    end

    if /(\d)-Day Rush/i === price_rows.to_s
      data['lead_time_rush'] = $1.to_i
    end
    if /24 hour rush/i === price_rows.to_s
      data['lead_time_rush'] = 1
    end

    it = doc.xpath("//table/tbody/tr/td/span[@class='black11']").last
    if it 
      data['lead_time_normal_min'], data['lead_time_normal_max'] = it.inner_html.scan(/(?:(?:(\d+)\s*-\s*)?(\d+) days)|(?:(?:(\d+)\s*-\s*)?(\d+) weeks)/).collect { |dl, dh, wl, wh| dh ? [dl ? dl.to_i : dh.to_i, dh.to_i] : [(wl ? wl.to_i : wh.to_i)*5, wh.to_i*5] }.max
    else
      data['lead_time_normal_min'] = 3
      data['lead_time_normal_max'] = 5
    end

    variant_prices.delete_if { |k, v| v.empty? }

    if variant_prices.empty?
      puts "URL: #{url} (SKIPPED, NO PRICES)" 
      puts log unless log.empty?
      return nil
    end

    if variant_prices.values.flatten.compact.empty?
      puts " * No price breaks"
      return nil
    end

    special = true if price_rows.size > 1

    begin
      price_code = price_codes['now']
      price_code = price_codes['standard'] unless price_code
      price_code = price_codes[nil] if price_codes.has_key?(nil)
      price_codes.default = price_code
    end  
    
    maximum = variant_prices.values.collect { |prices| prices.last[:minimum] }.max
    
    standard_price = variant_prices.delete('now') 
    standard_price = variant_prices.delete('standard') unless standard_price
    standard_price = variant_prices.delete(nil) if variant_prices.has_key?(nil)
    unless standard_price
      puts " * No Price"
      return nil
    end

    puts "Variant: #{variant_prices.inspect}"
    puts "Code: #{price_codes.inspect}"
    
    # Colors (Variants)  
    variants = []  
    href_reg = /\(.*?,\"(.*?)\"/
    num_reg = /\/(.*?)\./
    color_list = doc.xpath("//span[@id='ctl00_content_ColorLinks']/a")
    return nil if color_list.empty?
    variants = color_list.collect do |a|
      name = a.inner_html
      img = href_reg.match(a['href']).to_a[1]
      all, num = num_reg.match(img).to_a
      prices = variant_prices.delete(name.downcase)
      prices = standard_price unless prices
      costs = nil
      discounts = price_codes[name.downcase]
      if price_no_special
        price_code = price_codes[name.downcase]
        price_code = ((0...prices.size).collect { price_code.first } + price_code)[0...prices.size]
        costs = prices.zip(price_code).collect do |price, code|
          { :fixed => Money.new(0),
            :minimum => price[:minimum],
            :marginal => (price[:marginal] * (1.0 - code)).round_cents }
        end
      else
        costs = [{ :fixed => Money.new(0),
                   :minimum => prices.first[:minimum],
                   :marginal => (prices.last[:marginal] * (1.0 - discounts.last)).round_cents }]
      end
      
      unless price_no_less
        costs.unshift({ :fixed => Money.new(44.00),
                        :minimum => (prices.first[:minimum] / 2.0).ceil,
                        :marginal => (prices.first[:marginal] * (1.0 - discounts.first)).round_cents })
      end
      costs.push({ :minimum => (maximum * 1.5).to_i })
      
      { 'supplier_num' => num,
        'prices' => prices,
        'costs' => costs,
        'color' => name
      }
    end
    
    puts "Categories: #{categories.inspect}"
    
    data.merge!({
      'description' => features ? features.join("\n").strip : '',
      'decorations' => [], #decorations,
      'variants' => variants,
      'tags' => tag ? [tag] : (special ? ['Special'] : nil),
                  'supplier_categories' => categories.collect { |c| [c] }
    })
    
    
    # Shipping
    shipping = doc.xpath("//td[@id='ctl00_content_ShippingManualCell']/span/text()")
    unless shipping.empty?
      shipping = shipping.first.content 
    
      reg = /^(\d{1,4}) pieces per carton, (\d{1,3}(?:\.\d{1,2})?) lbs per carton, carton size (.*)$/
      all, pkg_pieces, pkg_weight, pkg_size = reg.match(shipping).to_a
      if all
        dim = parse_volume(pkg_size)
        
        data = data.merge({
          'package_weight' => Float(pkg_weight),
          'package_units' => Integer(pkg_pieces),
          'package_unit_weight' => 0.0,
          'package_height' => dim['h'],
          'package_width' => dim['w'],
          'package_length' => dim['l']
        })
      else
        puts "Unknown shipping: #{shipping.inspect}"
      end
    end
    
    short_num = begin
        pre,num = data['supplier_num'].split('-')
        "#{pre}#{num.to_i}"
    end
    data['image-thumb'] = TransformImageFetch.new("http://www.primeline.com/Products/Product_Images/#{short_num}.jpg")
    
    hi_res = doc.xpath("//span[@id='ctl00_content_HiReslink']/a")
    unless hi_res.empty?
      path = "http://www.primeline.com/#{hi_res.first['href']}"
      data['image-main'] = TransformImageFetch.new(path)
      data['image-large'] = CopyImageFetch.new(path)
    else
      data['image-main'] = TransformImageFetch.new("http://www.primeline.com/Products/#{main_img}")
    end
    
    unless log.empty?
      puts "URL: #{url}"     
      puts log.join("\n")
    end

    data
  end

  @@decoration_replace = {
    'Silk Screened' => ['Screen Print', 5],
    'Silk-screened' => ['Screen Print', 5],
    'Silk screened' => ['Screen Print', 5],
    'Debossed' => ['Deboss', 1],
    'Laser Engraved' => ['Laser Engrave', 1],
    'Laser Engraved with Oxidation' => ['Laser Engrave', 1],
    'Laser Engraved with Oxidization' => ['Laser Engrave', 1],
    'Laser Personalization' => ['Laser Engrave', 1],
    'Pad Printed' => ['Pad Print', 1],
    'Pad Printed outside' => ['Pad Print', 1],
    'Image Bonding®' => ['Image Bonding', 1],
    'VibraTec' => ['Four Color', 1],
    'Four-Color Process Offset' => ['Four Color', 1],
    'Four-Color Process Digital Label' => ['Four Color', 1],
    'Four-Color Process Digital Label for insert' => ['Four Color', 1],
    'Four-Color Process Digital Label with protective epoxy dome' => ['Four Color', 1],
    'Four-Color Process Offset protected by an epoxy dome' => ['Four Color', 1],
    'Hand applied' => ['H?', 1],
  }

  @@decoration_limit = {
    'one color only' => 1,
#    'one position only' => 1,
    'one color only, one position only' => 1,
    'one color only on can holder' => 1,
    'two colors only' => 2,
    'up to two colors' => 2,
    'two colors only due to registration' => 2,
    'one color, one position only' => 1,
    'two or more colors' => 5,
    'up to four colors' => 4,
  }

  def parse_products
    @products.each do |product|
      log = []

      # Decorations
      size = nil
      imprint_area = {}
      imprint_area.default = []
      imprint_method = {}
      imprint_method.default = []

#      puts "test: #{product['properties']}"

      product.delete('properties').each do |name, value|
        name, name_sub = name.split(',')
#        value, post = value.tr("\302\240",'').tr("\n",'').tr("\r",'').split(/\t|(?:   )/).collect { |e| e unless e.empty? }.compact
        name_sub = name_sub && name_sub.strip.downcase

        case name.strip.downcase
        when 'size'
          log << "  * Already has size" if size
          size = parse_volume(value)
          log << "  Size: #{size.inspect}"
          
        when 'imprint area'
          if /^(.+?(?:(?:\"?h)|(?:sq\.)|(?:dia\.)|(?:triangle)))(.*)$/ =~ value
            area_str, location = $1, $2.strip
            location = nil if location and location.empty?
            area = parse_area(area_str)
            log << "  Area: #{name_sub}: #{area.inspect} #{location.inspect}"

#            raise "Multiple imprint areas of type: #{name_sub_norm}" if imprint_area.has_key?(name_sub)
            imprint_area[name_sub] += [[location, area]]
          else
            log << "  * Area: #{value.inspect}"
          end
          
        when 'imprint method'
          /^(.+?)(\s+(?:–|-|(?:on))\s+.+?)?(?:\.\s*(.+))?$/ =~ value
          technique, tail, comment = $1, $2, $3
          if tail
            /(\s+(?:–|-)\s+(.+))/ =~ tail
            modify_all, modify = $1, $2
            /(\s+on\s+(.+))/ =~ tail
            location_all, location = $1, $2
            location = nil if location and location.empty?
            
            if modify_all and location_all
              modify = modify[0...modify.index(location_all)].strip if modify.include?(location_all)
              location = location[0...location.index(modify_all)].strip if location.include?(modify_all)
            end
          end

          technique, limit = @@decoration_replace[technique]
          
          if modify
            it = @@decoration_limit[modify]
            limit = it if it
#            modify = it ? it : "X(#{modify})"
          end
          
#          raise "Multiple imprint methods of type: #{name_sub}" if imprint_method.has_key?(name_sub)
          imprint_method[name_sub] += [[technique, limit, location]]
          log << "  Method: #{name_sub}: #{value.inspect} => #{technique.inspect} : #{limit.inspect} #{location.inspect} : #{comment.inspect}"
          
#        when 'packaging options'
          # Ignore
          # 
#        when 'packaging'
#          puts "Packaging: #{value.inspect}"
        
#        when 'ink cartridge'
        
        else
          log << "  * #{name.inspect}, #{name_sub.inspect}: #{value.inspect}"
        end
      end

      decorations = []

      (imprint_area.keys + imprint_method.keys).uniq.each do |name|
        imprint_method[name].each do |technique, limit, method_location|
          imprint_area[name].each do |area_location, area|
            decorations << {
              'technique' => technique,
              'limit' => limit,
              'location' => area_location || method_location}.merge(area || {})
          end
        end
      end
      
      log << "  * NO Decorations" if decorations.empty?
      
      decorations.unshift({
                            'technique' => 'None',
                            'location' => ''
                          })

      product['variants'].each { |v| v['dimension'] = size }
      product['decorations'] = decorations

      unless log.empty?
        puts "Product: #{product['supplier_num']}"     
        puts log.join("\n")
      end

#      puts "Dec: #{decorations.inspect}"
      puts "Lead: #{product['lead_time_rush']}"

      add_product(product)
    end
  end
end
