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
      if f and f['ctl00$content$cboPerPage'] != '0'
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
    doc = WebFetch.new('http://www.primeline.com/').get_doc
    categories = {}
    categories.default = []
    parent_category = nil
#    doc.xpath("//a").each do |a|
    doc.xpath("/html/body/div/table/tr/td/table/tr/td/font/a").each do |a|
#      next unless a['href'].include?('/Products/ProductList.aspx')
#      next if a.inner_html.include?('<img')
      next unless /^\/|(?:http:\/\/www\.primeline\.com\/)/ === a['href']
      next if a['href'].include?('/General')

      url = a['href'].gsub(/^\.\.\//, '')

      category_name = a.inner_html.encode('ASCII', :invalid => :replace, :undef => :replace, :replace => '').strip.gsub(/\s+/, ' ').gsub(/<.*?>/,'').gsub(/&.+;/, '')
      case a['class']
      when 'footerLinks_Form'
        parent_category = category_name
        categories[url] += [[category_name]]
      when 'footerSubLinks_Form'
        categories[url] += [[parent_category, category_name]]
      else
        categories[url] += [[category_name]]
      end
    end

    puts "Categories"
    categories.each do |path, category_list|
      url = (/^http:\/\// === path) ? path : "http://www.primeline.com/#{path}"

      process_category(category_list.uniq, url)
    end
  end

  def process_category(categories, url)
    unless doc = get_parser(url)
      puts "  #{url}  #{categories.inspect} CAN'T PARSE"
      return
    end
    count = 0
    doc.xpath("//a").each do |a|
      next unless a['href'] and a['href'].index('ProductDetail')
      path = a['href'].strip.gsub(/^(\.\.\/)|(http:\/\/primeline\.com\/)/, '')
      @product_pages[path] += categories
      count += 1
    end
    puts "  #{url}  #{categories.inspect} #{count}"
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
    products_list('nonstock').each { |p| @product_pages[p] = [['Overseas']] }
   

    # Fetch Images
    image_paths = %w(BT LG LT PL).collect { |p| "product_imagesNoLogo/#{p}-BlankImages" }
    image_paths += %w(BuiltImages LeemanImages LogoTec PL-0-3000 PL-3001-6000 PL-6001-9999).collect { |p| "product_images/#{p}/300dpi" }
    @image_list = get_ftp_images('ftp.primeworld.com', image_paths) do |path, file|
      (/^([A-Z]{2})(\d{3,4})(\w*)HIRES(\d?)\.{1,2}jpg$/i === file) && 
        ["#{path}/#{file}", "#{$1}-#{"%04d" % $2.to_i}", $3, path.include?('BlankImages') ? 'blank' : nil]
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
    'Silk Screen' => ['Screen Print', 5],
    'Silk Screened up to three colors' => ['Screen Print', 3],
    'Debossed' => ['Deboss', 1],
    'Deboss' => ['Deboss', 1],
    'Laser Engraved' => ['Laser Engrave', 1],
    'Laser Engraved with Oxidation' => ['Laser Engrave', 1],
    'Laser Engraved with Oxidization' => ['Laser Engrave', 1],
    'Laser Personalization' => ['Laser Engrave', 1],
    'Pad Print' => ['Pad Print', 3],
    'Pad Printed' => ['Pad Print', 3],
    'Pad printed' => ['Pad Print', 3],
    'Pad Printed (for multi-color)' => ['Pad Print', 3],
    'Pad Print (for multi-color)' => ['Pad Print', 3],
    'Pad Printed outside' => ['Pad Print', 1],
    'Image Bonding®' => ['Image Bonding', 1],
    'Image Bonding® 4-Color Process' => ['4 Color Photographic', 1],
    'VibraTec' => ['4 Color Photographic', 1],
    'VibraTec+ Drinkware' => ['4 Color Photographic', 1],
    '4-Color Process' => ['4 Color Photographic', 1],
    'Four-color Process Offset' => ['4 Color Photographic', 1],
    'Four-Color Process Offset' => ['4 Color Photographic', 1],
    'Four-Color Process Offset inside' => ['4 Color Photographic', 1],
    'Four-Color Process Digital Label' => ['4 Color Photographic', 1],
    'Four-Color Process Digital Label for insert' => ['4 Color Photographic', 1],
    'Four-Color Process Digital Label with protective epoxy dome' => ['4 Color Photographic', 1],
    'Four-Color Process Offset protected by an epoxy dome' => ['4 Color Photographic', 1],
    'Hand applied' => ['H?', 1],
    'Embroidery up to 7,500 stitches and 7 colors; Production time: 7' => ['Embroidery', 7500],
    'Embroidery up to 7,500 stitches and 7 colors; Production time: 7-10 business days; no rush service available' => ['Embroidery', 7500],
    'Embroidery (Price includes up to 12,000 stitches)' => ['Embroidery', 7500],
    'Transfer' => ['Heat Transfer', 3],
    'Transfer (for multi-color)' => ['Heat Transfer', 3],
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
    puts "Processing: #{categories.inspect} #{tag.inspect} #{url}"
    fetch = WebFetch.new(url)
    doc = Nokogiri::HTML(open(fetch.get_path), nil, 'UTF-8')
    return nil unless doc

    ProductDesc.apply(self) do |pd|
      pd.supplier_num = doc.xpath("//span[@id='ctl00_content_ProductCode']").inner_html.strip
      pd.name = doc.xpath("//span[@id='ctl00_content_ProductName']").inner_html.split(' ').collect do |c|
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
            case href
            when /\/Products\/ProductDetail\.aspx\?fpartno=(.+)$/
              product = get_product($1)
              "<a href='#{product.web_id}'>#{child.inner_html.gsub($1,'').strip}</a>"
            when '/eco/eco-design.aspx'
              "eco-responsible™"
            when '/Safety/Polycarbonate.aspx'
              "Polycarbonate (contains BPA)"
            when '/leeman/'
              "Leeman New York Product"
            when '/BUILT'
              "BUILT Product"
            else
              warning 'Unkown URL', "#{pd.supplier_num} #{href}"
              next nil
            end
            
          when 'font', 'b'
            next nil if child.inner_html.downcase.include?('free ship') 
            child.inner_html.strip
            
          when 'img', 'br', 'span'
            nil
          else
            raise "Unknown element #{pd.supplier_num} #{child.name}"
          end
        end.compact.join(' ')
        line.blank? ? nil : line
      end.compact
      
      
      price_rows = doc.xpath("//tr[@id='ctl00_content_RegularPriceRow']/td/table/tr/td") +
        doc.xpath("//tr[@id='ctl00_content_CloseoutPriceRow']/td/table/tr/td")

      pd.tags << tag if tag
#      pd.tags << 'Special' if price_rows.size > 1

      if cat_node = doc.at_xpath("//span[@id='ctl00_content_ProductClasstext']")
        cat = cat_node.text.split('>').collect { |s| s.strip.capitalize }.flatten
        unless cat.empty? or categories.flatten.include?(cat)
          puts "CAT: #{cat.inspect}"
          categories += [cat]
          puts "CATS: #{categories.inspect}"
        end
      end

      # Lead Times
      case price_rows.to_s
      when /(\d)-Day Rush/i
        pd.lead_time.rush = $1.to_i
      when /24 hour rush/i
        pd.lead_time.rush = 1
      end
      
      if categories.flatten.find { |c| c.downcase.include?('overseas') }
        pd.lead_time.normal_min = 20
        pd.lead_time.normal_max = 60
      elsif it = doc.xpath("//table/tbody/tr/td/span[@class='black11']").last
        pd.lead_time.normal_min, pd.lead_time.normal_max = it.inner_html.scan(/(?:(?:(\d+)\s*-\s*)?(\d+) days)|(?:(?:(\d+)\s*-\s*)?(\d+) weeks)/).collect { |dl, dh, wl, wh| dh ? [dl ? dl.to_i : dh.to_i, dh.to_i] : [(wl ? wl.to_i : wh.to_i)*5, wh.to_i*5] }.max
      else
        pd.lead_time.normal_min, pd.lead_time.normal_max = 3, 5
      end
      
      pd.supplier_categories = categories
      
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
        price_str = tr.children[1].at_xpath('span/text()').to_s
        price_str += 'C' if price_str.length == 1 and price_str[0] > ?0 and price_str[0] <= ?9 #Kludge for 4 without C price
        price_str = nil if price_str.empty?
 

        rows = tr.children[1].xpath("table/tr/td/table/tr[td/font]")
        next unless rows and rows.length > 1
        
        minimums = rows.shift.xpath("//td[@align='right']/font/b").to_a.compact
        next if minimums.empty?
        minimums = minimums.collect { |m| m.inner_html.to_i }

        pd.tags << 'Closeout' if tr.parent.parent.parent.attributes['id'].value.include?('Closeout')
        
        rows.each do |row|
          head = row.xpath("td/span/font").first
          head = head.inner_html.downcase if head
#          puts "HEAD: #{head}"
          
          list = row.xpath("td/font").collect { |e| e.inner_html.strip.empty? ? nil : e.inner_html }.compact
          next nil if list.empty?
          
          begin
            pricing = variant_pricing[head] = PricingDesc.new
            minimums.zip(list).each do |min, price|
              next unless price
              begin
                pricing.add(min, price)
              rescue ValidateError => e
                raise e unless minimums.last == min
                add_warning(e)
              end
            end
            pricing.apply_code(price_str || '5R', :round => true)
            pricing.eqp_costs unless price_no_special
            pricing.ltm(44.00) unless price_no_less
            pricing.maxqty
          rescue PropertyError
            warning 'Price Row Error', "#{minimums.inspect} #{list.inspect}"
          end
        end
      end
      
      raise ValidateError, 'No Prices' if variant_pricing.empty?
      
      unless variant_pricing.default = [nil, 'now', 'standard'].collect { |k| variant_pricing[k] }.compact.first
        raise ValidateError, 'No Price'
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
      puts "ColorMAP: #{color_image_map.inspect}"
      pd.images = color_image_map[nil] || []

      pd.variants = product_list.zip(color_list).collect do |prod, color|
        VariantDesc.new(:supplier_num => prod,
                        :properties => { 'color' => color },
                        :pricing => variant_pricing[color.downcase],
                        :images => color_image_map[color] || [])
      end


      # HiRes Images not specific to variant
      if hi_res = doc.at_xpath("//span[@id='ctl00_content_HiReslink']/a")
        path = "http://www.primeline.com/#{hi_res['href']}"
        node = ImageNodeFetch.new(path.split('/').last, path)
        pd.images << node unless color_image_map.values.flatten.include?(node)
      end
      

      # Decorations
      imprint_area = {}
      imprint_area.default = []
      imprint_method = {}
      imprint_method.default = []
      size_list = []
      
#      puts "Properties:"
      doc.xpath("//td[@id='ctl00_content_TableCell1']/span").each do |span|
        raise "Unknown prop" unless /^\s*<b>\s*(.+?)\s*:\s*<\/b>\s*(.+?)\s*$/ =~ span.inner_html
        name, value = $1.strip.downcase, $2.strip
#        puts "  #{name} : #{value.inspect}"

        /^(?:(optional) )?(.+)$/ =~ name
        name, name_sub = $2, $1
        name_sum = nil if name_sub.blank?
        
        case name
        when 'size'
          size_list << value.strip
          
        when 'imprint area'
#          if /^(.+?(?:(?:\"?h)|(?:sq\.)|(?:dia\.)|(?:triangle)))(.*)$/ =~ value
          if /template/i =~ value
            imprint_area[name_sum] += [['Refer to template', {}]]

          elsif aspects = parse_area(value)
            if aspects[:left]
              warning 'Unexpected Imprint Area Left', aspects.delete(:left)
              next
            end

            location = if aspects[:right]
                         /^(– )?(on )?(.+)$/ =~ aspects.delete(:right)
                         $3
                       end

#            puts "  Imprint Area: #{name_sub}: #{aspects.inspect} #{location.inspect}"
            imprint_area[name_sub] += [[location, aspects]]
          end
          
        when 'imprint method'
          /^(.+?)(\s+(?:–|-|(?:on))\s+.+?)?(?:\.\s*(.+))?$/ =~ value
          technique_str, tail, comment = $1, $2, $3
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
          
          technique, limit = @@decoration_replace[technique_str]

          unless technique
            warning 'Unknown Technique', technique_str
            next
          end
          
          if modify
            it = @@decoration_limit[modify]
            limit = it if it
          end
          
          imprint_method[name_sub] += [[technique, limit, location]]
#          puts "  Imprint Method: #{name_sub}: #{value.inspect} => #{technique.inspect} : #{limit.inspect} #{location.inspect} : #{comment.inspect}"

        when 'packaging', 'ink cartridge'
          pd.properties[name] = value.strip unless value.blank?

        else
          warning 'Unknown Property', name
        end
      end

      # Apply size, some products have multiple size listings for different size aspects of the same product
      if size_list.length > 2
        pd.properties['dimension'] = size_list.join(', ')
      elsif value = size_list.first
        pd.properties['dimension'] = parse_dimension(value, true) || value.strip
      end
      
      pd.decorations = [DecorationDesc.none]

      imprint_method.default = nil
      
      (imprint_area.keys + imprint_method.keys).uniq.each do |name|
        imprint_area[name].each do |area_location, area|
          (imprint_method[name] || imprint_method[nil] || []).each do |technique, limit, method_location|
            dec = DecorationDesc.new(:technique => technique,
                                     :limit => limit,
                                     :location => area_location || method_location || '')
            dec.merge!(area) if area
            pd.decorations << dec
          end
        end
      end
      

      # Shipping
      if shipping = doc.at_xpath("//td[@id='ctl00_content_ShippingManualCell']/span/text()")
        if /^(?<units>\d{1,4}) pieces per carton, (?<weight>\d{1,3}(?:\.\d{1,2})?) lbs per carton, carton size (?<size>.*)$/ =~ shipping.to_s
          pd.package.weight = Float(weight)
          pd.package.units = Integer(units)
          pd.package.merge!(parse_dimension(size))
        else
          warning "Unknown Shipping", shipping.inspect
        end
      else
        warning 'No Shipping'
      end

    end # ProductDesc.apply
  end # process_product
end
#PL-2535
