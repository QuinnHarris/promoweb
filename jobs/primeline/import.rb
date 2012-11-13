# -*- coding: utf-8 -*-
class PrimeLineWeb < GenericImport 
  def initialize
    super "Prime Line"
  end

  def imprint_colors
    %w(Yellow 116 1235 021 1787 199 202 208 225 267 2925 287 281 Process\ Blue Reflex\ Blue 327 Green 347 343 4635 423 877 873 Black White)
  end

  def get_parser(url)
    wf = WebFetch.new(url)
    if wf.fetch?
      puts "Fetching: #{url}"
      file = url.split('/').last.gsub('%20','+')
      page = @agent.get(url)
      puts "File: #{file.inspect}"
      f = page.form_with(:action => file)
      if f['ctl00$content$cboPerPage'] != '0'
        puts "  Refetch: #{f['ctl00$content$cboPerPage']}"
        f['ctl00$content$cboPerPage'] = '0' # All Items
        page = f.click_button
      end
      FileUtils.mkdir_p(File.split(wf.path).first)
      File.open(wf.path, "w:#{page.body.encoding}") { |file| file.write(page.body) }
      page.parser
    else
      Nokogiri::HTML(open(wf.path))
    end
  end

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
      if /^http:\/\// === path
        url = path
      else
        url = "http://www.primeline.com/#{path}"
      end
      process_category(category_list.uniq.join(' '), url)
    end
  end

  def process_category(category, url)
    puts "Category: #{url}  #{category}"
    doc = get_parser(url)
    count = 0
    doc.xpath("//table/tr/td/div/a").each do |a|
      next unless a['href'].index('ProductDetail')
      path = a['href'].strip.gsub(/^\.\.\//, '')
#      puts "Product: #{path} : #{category}"
      @product_pages[path] = (@product_pages[path] || []) + [category]
      count += 1
    end
    puts "  Products: #{count}"
  end

  def products_list(name)
    url = "http://www.primeline.com/Products/ProductList.aspx?SearchType=#{name}"
    get_parser(url).xpath("//table/tr/td/div/a").collect do |a|
      next nil unless a['href'].index('ProductDetail')
      a['href'].strip.gsub(/^\.\.\//, '')
    end
  end
  
  def parse_products
    # Fetch all index pages
    @tags = {}
    @product_pages = {}
    @product_pages.default = []

    @agent = Mechanize.new
    process_root

    products_list('New').each { |p| @tags[p] = 'New' }
    products_list('Specials').each { |p| @tags[p] = 'Special' }
    products_list('HotDeals').each { |p| @tags[p] = 'Special' }
    products_list('Closeouts').each { |p| @tags[p] = 'Closeout' }
    products_list('nonstock').each { |p| @product_pages[p] = ['Overseas'] }
   

    # Fetch Images
    image_paths = %w(BT LG LT PL).collect { |p| "product_imagesNoLogo/#{p}-BlankImages" }
    image_paths += %w(BuiltImages LeemanImages LogoTec PL-0-3000 PL-3001-6000 PL-6001-9999).collect { |p| "product_images/#{p}/300dpi" }
    @image_list = get_ftp_images('ftp.primeworld.com', image_paths) do |path, file|
      (/^([A-Z]{2})(\d{4})(\w*)HIRES(\d?)\.jpg$/i === file) && 
        ["#{path}/#{file}", "#{$1}-#{$2}", $3, path.include?('BlankImages') ? 'blank' : nil]
    end

  
    puts "Processing #{@product_pages.length} products"
    @product_pages.each do |path, categories|
      process_product(categories, "http://www.primeline.com/#{path}", @tags[path])
    end
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
    'VibraTec' => ['4 Color Photographic', 1],
    'Four-Color Process Offset' => ['4 Color Photographic', 1],
    'Four-Color Process Digital Label' => ['4 Color Photographic', 1],
    'Four-Color Process Digital Label for insert' => ['4 Color Photographic', 1],
    'Four-Color Process Digital Label with protective epoxy dome' => ['4 Color Photographic', 1],
    'Four-Color Process Offset protected by an epoxy dome' => ['4 Color Photographic', 1],
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

  def process_product(categories, url, tag)
    puts "Processing: #{url}"
    fetch = WebFetch.new(url)
    doc = Nokogiri::HTML(open(fetch.get_path), 'ASCII')
    return nil unless doc

    ProductDesc.apply(self) do |pd|
      pd.supplier_num = doc.xpath("//span[@id='ctl00_content_ProductCode']").inner_html.strip
      pd.name = iconv(doc.xpath("//span[@id='ctl00_content_ProductName']").inner_html).split(' ').collect do |c|
        @@upcases.index(c.upcase.gsub(/\d/,'')) ? c.upcase : c.capitalize
      end.join(' ')
      

      main_img = doc.xpath("//img[@id='ctl00_content_PIM']").first['src']
      return nil if main_img == "Product_Images/picturesoon.jpg"
      
      note = doc.xpath("//span[@id='ctl00_content_ProductClasstext']").to_a
      return nil if note and note.first.inner_html == "Non-Stock"
      
      
      # Features
      pd.description = doc.xpath("//img[@src='images/bulletArrow.gif']").collect do |img|
        line = img.next_sibling.children.collect do |child|
          next child.text.strip if child.text?
          case child.name
          when 'a'
            next nil unless child.attributes['href']
            href = child.attributes['href'].value.strip
            unless /\/Products\/ProductDetail\.aspx\?fpartno=(.+)$/ === href
              warning 'Unkown URL', "#{pd.supplier_num} #{href}"
              next nil
            end
            product = get_product($1)
            "<a href='#{product.web_id}'>#{child.inner_html.gsub($1,'').strip}</a>"
            
          when 'font', 'b'
            next nil if child.inner_html.downcase.include?('free ship') 
            child.inner_html.strip
            
          when 'img', 'br'
            nil
          else
            raise "Unknown element #{data['supplier_num']} #{child.name}"
          end
        end.compact.collect { |s| s.encode('ISO-8859-1') }.join(' ')
        line.blank? ? nil : line
      end.compact
      
      
      price_rows = doc.xpath("//tr[@id='ctl00_content_RegularPriceRow']/td/table/tr/td") +
        doc.xpath("//tr[@id='ctl00_content_CloseoutPriceRow']/td/table/tr/td")

      pd.tags << 'Special' if price_rows.size > 1
      
      # Lead Times
      case price_rows.to_s
      when /(\d)-Day Rush/i
        pd.lead_time.rush = $1.to_i
      when /24 hour rush/i
        pd.lead_time.rush = 1
      end
      
      if categories.include?('Overseas')
        pd.lead_time.normal_min = 20
        pd.lead_time.normal_max = 60
      elsif it = doc.xpath("//table/tbody/tr/td/span[@class='black11']").last
        pd.lead_time.normal_min, pd.lead_time.normal_max = it.inner_html.scan(/(?:(?:(\d+)\s*-\s*)?(\d+) days)|(?:(?:(\d+)\s*-\s*)?(\d+) weeks)/).collect { |dl, dh, wl, wh| dh ? [dl ? dl.to_i : dh.to_i, dh.to_i] : [(wl ? wl.to_i : wh.to_i)*5, wh.to_i*5] }.max
      else
        pd.lead_time.normal_min, pd.lead_time.normal_max = 3, 5
      end
      
      pd.supplier_categories = categories.collect { |c| [c] }
      
      price_no_special = nil
      price_no_less = nil
      price_note = doc.xpath("//span[@id='ctl00_content_PriceNote']").to_a.join.strip
      unless price_note.empty?
        price_note = price_note.downcase
        price_no_special = true if price_note.index('special pricing') 
        price_no_less = true if price_note.index('less than minimum')
      end
      
      setup_price = doc.xpath("//span[@id='ctl00_content_SetupCostDesc']").first.inner_html
      running_price = doc.xpath("//span[@id='ctl00_content_RunningCostDesc']").first
      running_price = running_price.inner_html if running_price
      #    @decoration_costs << [setup_price ? setup_price.strip : nil, running_price ? running_price.strip : nil]
      
      variant_pricing = {}


      
      doc.xpath("//tr[@id='ctl00_content_RegularPriceRow' or @id='ctl00_content_CloseoutPriceRow']/td/table/tr").each do |tr|
        price_row = tr.children[0]

        price_str = tr.children[1].at_xpath('span/text()').to_s
        price_str += 'C' if price_str.length == 1 and price_str[0] > ?0 and price_str[0] <= ?9 #Kludge for 4 without C price
        price_str = nil if price_str.empty?
 

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
          
          begin
            pricing = PricingDesc.new
            minimums.zip(list).each do |min, price|
              next unless price
              pricing.add(min, price)
            end
            pricing.apply_code(price_str || '5R')
            pricing.eqp_costs unless price_no_special
            pricing.ltm(44.00) unless price_no_less
            pricing.maxqty
            variant_pricing[head] = pricing
          rescue PropertyError
            puts " Price Row Error: #{minimums.inspect} #{list.inspect}"
          end
        end
      end
      
      raise ValidateError, 'No Prices' if variant_pricing.empty?
      
      unless variant_pricing.default = [nil, 'now', 'standard'].collect { |k| variant_pricing[k] }.compact.first
        raise ValidateError, 'No Price'
      end
      

      # Decorations
      imprint_area = {}
      imprint_area.default = []
      imprint_method = {}
      imprint_method.default = []
      
      puts "Properties:"
      doc.xpath("//td[@id='ctl00_content_TableCell1']/span").each do |span|
        raise "Unkonown prop" unless /^\s*<b>\s*(.+?)\s*:\s*<\/b>\s*(.+?)\s*$/ =~ span.inner_html
        name, value = $1.strip.downcase, iconv($2.strip)
        puts "  #{name} : #{value.inspect}"
        
        name, name_sub = name.split(/\s*,\s*/)
        
        case name
        when 'size'
          warning 'Already has dimension', pd.properties['dimension'] if pd.properties['dimension']
          pd.properties['dimension'] = parse_dimension(value) || value.strip
          
        when 'imprint area'
          if /^(.+?(?:(?:\"?h)|(?:sq\.)|(?:dia\.)|(?:triangle)))(.*)$/ =~ value
            area_str, location = $1, $2.strip
            location = nil if location and location.empty?
            area = parse_dimension(area_str)
            puts "  Area: #{name_sub}: #{area.inspect} #{location.inspect}"
            
            #            raise "Multiple imprint areas of type: #{name_sub_norm}" if imprint_area.has_key?(name_sub)
            imprint_area[name_sub] += [[location, area]]
          else
            warning 'Unknown Area', value.inspect
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

          unless technique
            warning 'Unknown Technique', technique
            next
          end
          
          if modify
            it = @@decoration_limit[modify]
            limit = it if it
            #            modify = it ? it : "X(#{modify})"
          end
          
          #          raise "Multiple imprint methods of type: #{name_sub}" if imprint_method.has_key?(name_sub)
          imprint_method[name_sub] += [[technique, limit, location]]
          puts "  Method: #{name_sub}: #{value.inspect} => #{technique.inspect} : #{limit.inspect} #{location.inspect} : #{comment.inspect}"
          
          #        when 'packaging options'
          # Ignore
          # 
          #        when 'packaging'
          #          puts "Packaging: #{value.inspect}"
          
          #        when 'ink cartridge'
          
        else
          warning 'Unknown Property', name
        end
      end
      
      pd.decorations = [DecorationDesc.none]
      
      (imprint_area.keys + imprint_method.keys).uniq.each do |name|
        imprint_method[name].each do |technique, limit, method_location|
          imprint_area[name].each do |area_location, area|
            dec = DecorationDesc.new(:technique => technique,
                                     :limit => limit,
                                     :location => area_location || method_location || '')
            dec.merge!(area) if area
            pd.decorations << dec
          end
        end
      end

            
      # Colors (Variants)
      product_list = []
      color_list = []
      doc.xpath("//span[@id='ctl00_content_ColorLinks']/a").collect do |a|
        raise "Unknown HREF: #{a['href']}" unless /\(.*?,\"(.*?)\"/ === a['href']
        img = $1
        raise "Unknown Num: #{img}" unless /\/(.*?)\./ === img
        product_list << $1
        color_list << a.inner_html.strip
      end
      raise ValidateError, 'No Colors' if color_list.empty?

      
      color_image_map, color_num_map = match_colors(color_list)
      pd.images = color_image_map[nil]
      
      pd.variants = product_list.zip(color_list).collect do |prod, color|
        VariantDesc.new(:supplier_num => prod,
                        :properties => { 'color' => color },
                        :pricing => variant_pricing[color.downcase],
                        :images => color_image_map[color] || [])
      end
      
      
      # Shipping
      shipping = doc.xpath("//td[@id='ctl00_content_ShippingManualCell']/span/text()")
      unless shipping.empty?
        shipping = shipping.first.content 
        
        reg = /^(\d{1,4}) pieces per carton, (\d{1,3}(?:\.\d{1,2})?) lbs per carton, carton size (.*)$/
        all, pkg_pieces, pkg_weight, pkg_size = reg.match(shipping).to_a
        if all
          dim = parse_dimension(pkg_size)
          
          pd.package.weight = Float(pkg_weight)
          pd.package.units = Integer(pkg_pieces)
          pd.package.height = dim['h']
          pd.package.width = dim['w']
          pd.package.length = dim['l']
        else
          puts "Unknown shipping: #{shipping.inspect}"
        end
      end
      
      hi_res = doc.xpath("//span[@id='ctl00_content_HiReslink']/a")
      unless hi_res.empty?
        path = "http://www.primeline.com/#{hi_res.first['href']}"
        pd.images = [ImageNodeFetch.new(path.split('/').last, path)]
      end
    end
  end
end
