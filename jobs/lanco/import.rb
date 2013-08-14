class LancoXLS < GenericImport
  def initialize
    super "Lanco"

    @decorations = {}

#    @src_urls = 'http://www.lancopromo.com/downloads/LANCO-ProductData.zip'
    @src_file = File.join(JOBS_DATA_ROOT, "Lanco.xls")
  end

  def imprint_colors
    %w(340 3305 Process\ Blue Reflex\ Blue 2935 116 021 186 209 320 2597 871 Black White 877 876 281 CoolGray\ 7 476 190)
  end

  @@image_path = "http://www.lancopromo.com/images/products/"
  def image_path(web_id)
    "#{@@image_path}#{web_id.downcase}/"
  end

  @@fills = {
    'A' => %w(Animal\ Crackers Caramel\ Popcorn Honey\ Roasted\ Peanuts Gold\ Fish Jelly\ Beans Mini\ Pretzels Peanuts Red\ Hots Starlight\ Mints Tootsie\ Rolls),
    'B' => %w(Candy\ Corn Choc\ Covered\ Peanuts Choc\ Covered\ Rasins Gum\ Balls Gummy\ Bears Gummy\ Worms Pistachios Runts Sour\ Patch\ Kids Supermints Swedish\ Fish Teenie\ Beenies Trail\ Mix),
    'C' => %w(Granola American\ Flag\ Balls Cashews Milk\ Choc\ Balls Chocolate\ Coins Choc\ Covered\ Almonds Choc\ Covered\ Pretzels Christmas\ Balls Earth\ Balls Easter\ Eggs English\ Butter\ Toffee Chocolate\ Squares Halloween\ Balls Hershey\ Kisses Jelly\ Bellies M&Ms Pecan\ Turtles Red\ Foil\ Choc\ Hearts Choc\ Covered\ Sunflower\ Seeds Soy\ Nuts Sports\ Balls Truffles)
  }
    
#  def decorations(product)
#    product['imprint_area']
#    'ImprintType'
#    'SetupCharge'
#    'SetupChargeCode'
#    'RunningCharge'
#    'RunningChargeCode'
#    'SetupCharge_4c'
#    'SetupChargeCode_4c'
#    'RunCharge_4c'
#    'RunChargeCode_4c'
#  end

  def test_decorations(product)
    vals = %w(ImprintType SetupCharge SetupChargeCode RunningCharge RunningChargeCode).collect do |name|
      product[name]
    end

    @decorations[vals] = true
  end

  def decorations(product)
    test_decorations(product)

    sizes = [product['imprint_area']].uniq.collect do |string|
      next unless string
      string.split(/\s*[,;]\s*/).collect do |str|
        hash = {}
        case str
        when 'Full Bleed'
          next { :location => 'Full Bleed' }
        when 'N/A'
          next
        when /^(.+?)- spot color$/
          str = $1
        when /^(.+?)\s*\((.+?)\)\s*$/
          str = $1
          hash = { :location => $2 }
        end
        dim = parse_dimension(str)
        dim ? dim.merge(hash) : nil
      end
    end.flatten.compact
    sizes = [{}] if sizes.empty?

    product['Order_info'].gsub('&nbsp;', ' ').scan(/(?:\n)?([\w\s]+)::?\s*\s*(.+?)(?:\r|$)/im).each do |name, str|
      matches = [/add $(\d{2,3})(?:\(\w\))? +per color,? up to (\d) colors/im,
                 /Set-? ?up +(?:charges?:?)? *(?:is )?\$ ?(\d{2,3})(?:\(\w\))?(?: per color,? up to +(\d) +colors)?/im,
                 /\$(\d{2,3})(?:\(\w\))? +per +color,? up to +(\d) +colors/im,
                 /Set-? ?up +charge:? +(?:per +color)?(?:\/?(?:per +)?location)? +\$(\d{2,3})/,
                 /\$(\d{2,3})(?:\(\w\))? +set-up (?:charge)?(?: per color,? up to (\d) colors)?/im,
                 /(?:re-?order)|(?:repeat)/im
                ].collect do |regex|
        whole, price, count = regex.match(str).to_a
        whole && [str.index(whole), price, count]
      end.compact.sort_by { |i, p, c| i }

      unless matches.empty? or !matches.first[1]
        setup = Float(matches.first[1])
        limit = matches.first[2] && Integer(matches.first[2])
      end

      case str
      when /running charge \$(\d{0,1}\.\d{2})/im 
        running = Float($1)
      when /\$(\d{0,1}\.\d{2})(?:\(\w\))? +running +charge/im
        running = Float($1)
      end

      if setup == 45.0 && (limit == 1 || running == 0.2)
        return [DecorationDesc.none] + sizes.collect do |s|
          dd = DecorationDesc.new(:technique => 'Screen Print',
                                  :location => '',
                                  :limit => limit || 4)
          dd.merge!(s)
        end
      end
    end

    return []
  end

  def process_prices(product)
    pricing = PricingDesc.new

    (1..6).each do |n|
      minimum = Integer(product["Col#{n}MinQty"] || product["Col#{n}Min"])
      break if minimum == 0
      pricing.add(minimum, product["Col#{n}Price"])
    end
    pricing.apply_code(product['PriceCode'] || '5R')
#    pricing.eqp_costs
    pricing.maxqty #(pricing.prices.last[:minimum]*2)
    pricing.ltm_if(24.00, product['absoluteMin'])
    pricing
  end

  def find_common_list(orig_list)
#    puts "List: #{orig_list.inspect}"
    list = orig_list.collect { |s| s.split(/\s+/) }
    word_list = list.first
    word_list.size.downto(1) do |length|
      0.upto(word_list.size-length) do |offset|
        common = word_list.slice(offset, length).join(' ')
        unless list.find { |s| !s.join(' ').index(common) }
          return common, list.collect do |s|
            str = s.join(' ')
            i = str.index(common)
            str[i...(i+common.length)] = ""
            str.strip
          end
        end
      end
    end
    return nil, orig_list
  end

  def fetch_parse?
    return nil unless super

    agent = Mechanize.new
    page = agent.get('http://www.lancopromo.com/productdata')
    href = page.links.find { |l| /productdata/i =~ l.href }.href
    
    wf = WebFetch.new(href)
    return nil unless wf.fetch?
    path = wf.get_path

    puts "Unziping Data"
    dst_path = File.join(JOBS_DATA_ROOT,'lanco')
    out = `unzip -o #{path} -d #{dst_path}`
    list = out.scan(/inflating:\s+(.+?)\s*$/).flatten
    raise "More than one file" if list.length > 1
    FileUtils.ln_sf(list.first, @src_file)
  end

  def parse_products
    puts "Reading Excel: #{@src_file}"
    ws = Spreadsheet.open(@src_file).worksheet(0)
    ws.use_header
        
    products = []
    sub_products = {}
    sub_products.default = []
    ws.each(1) do |row|
      data = ws.header_map.each_with_object({}) { |(k, v), h| h[k] = row[v] }
      unless row['ParentID'].blank?
#        puts "Sub: #{data['ParentID'].inspect}"
        sub_products[data['ParentID']] += [data]
      else
        products << data
      end
    end

    file_name = cache_file("Lanco_Images")
    @image_list = cache_exists(file_name) ? cache_read(file_name) : {}
    begin
      puts "Fetching Image Lists:"
      products.each do |product|
        next if @image_list[web_id = product['ProductID']] or web_id.nil?
        print " #{web_id}"
        uri = URI.parse(image_path(web_id))
        txt = uri.open.read
        @image_list[web_id] = txt.scan(/<a href="([\w-]+\.jpg)">/).flatten
      end
      puts
    ensure
      cache_write(file_name, @image_list)
    end

    puts "Processing"
    
    products.each do |product|
      ProductDesc.apply(self) do |pd|
        pd.supplier_num = product['ProductID']
        pd.name = convert_name(product['Alt_Prod_Name'].empty? ? product['Prod_Name'] : product['Alt_Prod_Name'])
        
        doc = Nokogiri::HTML(product['Prod_Description'])
        description = doc.root.search('text()').collect { |n| n.text.strip }.find_all { |s| !s.empty? }.join("\n")
        
        # Replace Lanco Product ID references to our product ids
        description.scan(/\w{2,3}\d{3,4}/).each do |num|
          sub_products.find { |parent, list| list.find { |h| (h['ProductID'] == num) && (num = parent) } }
          if num == pd.supplier_num
            description.gsub!(num)
          else
            prod = get_product(num)
            description.gsub!(num, "<a href='#{prod.web_id}'>M#{prod.id}</a>")
          end
        end
        
        pd.description = description
        yes_list = ['YES', 'True', Date.parse("Sun, 31 Dec 1899 00:00:00 +0000")]
        pd.tags = {
          'New' => 'New',
          'Closeout' => 'Closeout',
          'isKosher' => 'Kosher',
          'MadeInUSA' => 'MadeInUSA',
        'isEcoFriendly' => 'Eco',
        }.collect { |method, name| name if yes_list.include?(product[method]) }.compact
        
        pd.supplier_categories = [[product['Category'] || 'unkown', product['Subcategory'] || 'unknown']]
        pd.package.unit_weight = product['shipping_info(wt/100)'].is_a?(String) ? (product['shipping_info(wt/100)'].to_f / 100.0) : nil
        
        # Lead Times
        raise "Unkown Lead: #{product['production_time']}" unless /(\d+)-(\d+) ((?:Business Days)|(?:weeks))/i === product['production_time']
        multiplier = $3.include?('weeks') ? 7 : 1
        pd.lead_time.normal_min = $1.to_i * multiplier
        pd.lead_time.normal_max = $2.to_i * multiplier
        
        # 0 - none
        # 1 - 3day, 1day, 2hr
        # 2 - 3day, 1day
        # 3 - 3day
        pd.lead_time.rush, pd.lead_time.rush_charge =
          case product['rush_svc_type'].to_i
          when 1,2
            [1, 1.25]
          when 3
            [3, 1.15]
          else
            [nil, nil]
          end
        
        
        image_list = @image_list[pd.supplier_num]
        image_list = image_list.collect { |img| ImageNodeFetch.new(img, "#{image_path(pd.supplier_num)}#{img}") }
        
        used_image_list = []
        
        if img = image_list.find { |img| img.id == "#{pd.supplier_num.downcase}.jpg" }
          used_image_list << img
          pd.images = [img]
        else
          #        puts "NO MAIN IMAGE"
        end
        
        
        # Decorations
        pd.decorations = decorations(product)
        
        # Match Colors to Images
        colors = product['colors'].split(/,\s*/)
        color_image = {}
        colors.each do |color|
          images = image_list.find_all do |img|
            img.id.include?(color.gsub("Translucent ", '').downcase)
          end
          if images.length > 0
            #          puts "MATCH: #{color} : #{images.join(', ')}"
            used_image_list += images
            color_image[color] = images
          else
            #          puts "NO MATCH: #{color}"
            color_image[color] = nil
          end
        end
        colors = [nil] if colors.empty?
        color_image[nil] = nil if color_image.empty?
        
        
        sub = sub_products[product['ProductID']]
        common, parts = find_common_list(([product] + sub).collect { |p| p['Prod_Name'].gsub(/(?:w\/)|(?:with)/i,'') })
        
        full_color = false
        if parts.length == 2 and parts[0].blank? and parts[1].include?('Full Color')
          parts = ['Color Print', 'Full Color']
          full_color = true
        end
        
        pd.variants = ([product] + sub).zip(parts).collect do |prod, fill_name|
          pricing = process_prices(prod)
          properties = { 'material' => prod['Materials'] }
          properties.merge!('dimension' => parse_dimension(prod['Prod_size1'])) if prod['Prod_size1']
          properties.merge!('imprint' => fill_name) if full_color
          
          color_image.collect do |color, images|
            vd = VariantDesc.new(:supplier_num => prod['ProductID'] + (color && "-#{color}").to_s,
                                 :properties => properties.merge('color' => color),
                                 :images => images || [], :pricing => pricing)
            
            next vd if full_color or sub.empty?
            
            if /^(A|B|C) Fill$/i === fill_name
              letter = $1
              next @@fills[letter].collect do |fill|
                v = vd.dup
                v.supplier_num = "#{vd.supplier_num[0..12]}-#{letter}-#{fill}"
                v.properties = v.properties
                  .merge('fill' => f = "#{letter}-#{fill}",
                         'swatch' => ImageNodeFile.new(f, File.join(JOBS_DATA_ROOT, 'Lanco-Fills-Swatches', "#{fill}.png")) )
                v
              end
            else
              path = File.join(JOBS_DATA_ROOT, 'Lanco-Fills-Swatches', "#{fill_name}.png")
              if File.exists?(path)
                swatch = ImageNodeFile.new(fill_name, path)
              else
                swatch = ImageNodeFile.new('Empty', File.join(JOBS_DATA_ROOT, "EmptySwatch.png"))
              end
              
              vd.properties.merge!('fill' => fill_name, 'swatch' =>  swatch)
            end
            
            vd
          end
        end.flatten
        
        # All Unassociated images
        unused_image_list = image_list - used_image_list
        unless unused_image_list.empty?
          #        puts "UNUSED IMG: #{unused_image_list.join(', ')}"
          pd.images += unused_image_list
        end
      end
    end
  end
end
