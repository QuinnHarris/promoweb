class LancoSOAP < GenericImport
  def initialize
    @client = Savon::Client.new do |wsdl, http, wsse|
      wsdl.document = File.expand_path("wsdl.wsdl")
      http.proxy = 'http://services.promocatalogonline.com/webservice.php'
      http.auth.basic('quinn', 'harris')
      http.read_timeout = 600
    end

    @image_list = {}
    
    super "Lanco"
  end

  def imprint_colors
    %w(340 3305 Process\ Blue Reflex\ Blue 2935 116 021 186 209 320 2597 871 Black White 877 876 281 CoolGray\ 7 476 190)
  end
  
  @@overrides = {
    'SBF397' => { :alt_Name => ['McKinley Embossed Mint Tin (empty)', 'McKinley Embossed Mint Tin'] },
    'MB200' => { :prod_name => ['Mesh Bags w/ AL100', 'Mesh Bag w/ AL100'] },
    'TG194' => { :prod_name => ['Tins Empty', 'Tin Empty'] },
  }
 
  @@image_path = "http://www.lancopromo.com/images/products/"

  def image_path(web_id)
    "#{@@image_path}#{web_id.downcase}/"
  end

  def get_images(web_id)
    return @image_list[web_id] if @image_list.has_key?(web_id)
    puts "Getting Image List for #{web_id}"
    uri = URI.parse(image_path(web_id))
    txt = uri.open.read
    @image_list[web_id] = txt.scan(/<a href="([\w-]+\.jpg)">/).flatten
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
  
  def process_prices(product)
    list = product.delete(:pricing)[:prices][:item]
    
    return {} if list.empty?
    
    cost_list = convert_pricecodes(product[:cost_code]).zip(list).collect do |perc, price|
      (Money.new(Float(list[:price])) * (1.0-perc)).round_cents if price
    end.compact
    
    costs = [
      { :fixed => Money.new(0),
        :minimum => Integer(list.first[:from_qty]),
        :marginal => cost_list.last,
      },
      { :minimum => (Integer(list.last[:from_qty]) * 1.5).to_i
      }
    ]
    
    min = (product['Order_Info'] =~ /less than min/i)   
    if prices.first[:minimum] != 1 and !min
      costs.unshift({ :fixed => Money.new(24.00),
        :minimum => (prices.first[:minimum] / 2.0).ceil,
        :marginal => cost_list.last,
      })
    end
    
    { 'prices' => prices, 'costs' => costs }
  end

  def decorations(product)
    sizes = [product[:imprint_size], product[:imprint_size2]].uniq.collect do |str|
      parse_area(str)
    end.compact
    sizes = [{}] if sizes.empty?

    product[:order_info].gsub('&nbsp;', ' ').scan(/(?:\n)?([\w\s]+)::?\s*\s*(.+?)(?:\r|$)/im).each do |name, str|
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
        return [{'technique' => 'None',
                  'location' => ''
                }] + sizes.collect do |s|
          s.merge({'technique' => 'Screen Print',
                    'limit' => limit || 4,
                    'location' => ''})
        end
      end
    end

    return []
  end
  
  def process_products(products)
    supplier_nums = {} # Web_Id => (our ID) mapping
    
    sub_products = {}
    sub_products.default = []
    products = products.find_all do |product|
      if product['ParentItem'].empty?
        supplier_nums[product[:web_id]] = get_id(product[:web_id])
        next true
      end
      supplier_nums[product[:web_id]] = get_id(product[:parent_item])
      sub_products[product[:parent_item]] += [product]
      false
    end.sort_by { |p| p[:prod_name] }
    
    products.each do |product|
      sub = sub_products[product[:web_id]]
      common, parts = find_common_list(([product] + sub).collect { |p| p[:prod_name].gsub(/(?:w\/)|(?:with)/i,'') })
      
      description = product[:prod_description].strip + "\n" + product[:order_info].strip
      description.gsub!('&nbsp;',' ')
      description.gsub!(/\s*\n\s*/,"\n")
      
      # Replace Lanco Product ID references to our product ids
      description.scan(/\w{2,3}\d{3,4}/).each do |num|
        next unless our_id = supplier_nums[num]
        description.gsub!(num, "<a href='#{our_id}'>#{our_id}</a>")
      end
      
      if parts.find { |s| s.include?('A Fill')}
        description += "\n<a href='/static/fills#a'><strong>A Fills:</strong></a> Animal Crackers, Carmel Popcorn, Red Hots, Goldfish, Jelly Beans, Mini Pretzels, Peanuts, Starlight Mints, Honey Roasted Peanuts, Tootsie Rolls"
        description += "\n<a href='/static/fills#b'><strong>B Fills:</strong></a> Gummy Bears, Gummy Worms, Runts, Pistachios, Chocolate Covered Peanuts, Chocolate Covered Raisins, Conversation Hearts, Candy Corn, Trail Mix, Teenie Beanies, Gumballs, Supermints, Swedish Fish, Sour Patch Kids"
        description += "\n<a href='/static/fills#c'><strong>C Fills:</strong></a> Pecan Turtles, Truffles, Chocolate Coins, Hershey Kisses, English Butter Toffee, Chocolate Covered Almonds, Chocolate Covered Pretzels, Red Foil Chocolate Hearts, Cashews, Cocolate Balls, Halloween Balls, Christmas Balls, Jelly Bellies, M&M'S, Earth Balls, Easter Eggs, Sports Balls, American Flag Balls, Foil Wrapped Chocolate Squares, Soy Nuts, Chocolate Covered Sunflower Seeds, Granola"
      end
      
      product_data = {
        'supplier_num' => product[:web_id],
        'name' => convert_name(product[:alt_name].empty? ? product[:prod_name] : product[:alt_name]),
        'description' => description,
        'decorations' => [],
        'tags' => {
          :is_new => 'New',
          :closeout => 'Closeout',
          :special => 'Special',
          :is_kosher => 'Kosher',
          :made_in_usa => 'MadeInUSA'
        }.collect { |method, name| name if product[method].to_i == 1 }.compact,
        'supplier_categories' => [[product[:category], product[:sub_category]]],
        'package_unit_weight' => product[:wt_100].to_f / 100.0
      }

      # Lead Times
      raise "Unkown Lead: #{product[:lead_time]}" unless /(\d+)-(\d+) ((?:Business Days)|(?:weeks))/i === product[:lead_time]
      multiplier = $3.include?('weeks') ? 7 : 1
      product_data['lead_time_normal_min'] = $1.to_i * multiplier
      product_data['lead_time_normal_max'] = $2.to_i * multiplier

#      puts "Rush: #{product_data['supplier_num']} : #{product[:rushservice_id]}"
      # 0 - none
      # 1 - 3day, 1day, 2hr
      # 2 - 3day, 1day
      # 3 - 3day
      product_data['lead_time_rush'], product_data['lead_time_rush_charge'] =
        case Integer(product[:rushservice_id])
        when 1,2
          [1, 1.25]
        when 3
          [3, 1.15]
        else
          [nil, nil]
        end

      product_data['lead_time_rush_charge']
      
      product_data['image-thumb'] = product_data['image-main'] = product_data['image-large'] = HiResImageFetch.new("http://www.lancopromo.com/images/products/#{product_data['supplier_num'].downcase}/#{product_data['supplier_num'].downcase}.jpg")
            
      puts

      image_list = get_images(product[:web_id])
      puts "List #{product[:web_id]}: #{image_list.inspect}"
      image_list = image_list.collect { |img| ImageNodeFetch.new(img, "#{image_path(product[:web_id])}#{img}") }

      used_image_list = []

      if img = image_list.find { |img| img.id == "#{product[:web_id].downcase}.jpg" }
        used_image_list << img
        product_data['images'] = [img]
      else
        puts "NO MAIN IMAGE"
      end


      # Decorations
      product_data['decorations'] = decorations(product)


      colors = product[:ext_colors].collect { |c| c.split(',') }.flatten.compact.collect { |c| c.strip }.sort
      puts "Colors: #{colors.inspect}"
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
          puts "NO MATCH: #{color}"
          color_image[color] = nil
        end
      end

      colors = [nil] if colors.empty?
      color_image[nil] = nil if color_image.empty?
      
      product_data['variants'] = ([product] + sub).zip(parts).collect do |prod, fill_name|
        price_data = process_prices(prod)
        price_data.merge!('dimension' => parse_volume(prod['Size_Description']))
        price_data.merge!('fill' => fill_name ) unless sub.empty?
        
        color_image.collect do |color, images|
#          puts "Color: #{color}  Img: #{images && images.join(', ')}"
          # For Each Variant
          { 'supplier_num' => prod['Web_Id'] + (color && "-#{color}").to_s,
            'color' => color,
            'images' => images
          }.merge(price_data)
        end
      end.flatten

      # All Unassociated images
      unused_image_list = image_list - used_image_list
      unless unused_image_list.empty?
        puts "UNUSED IMG: #{unused_image_list.join(', ')}"
        product_data['images'] += unused_image_list
      end
      
      add_product(product_data)
    end
  end

  def clean_value(value)
    case value
    when String
      value.strip!
    when Hash
      value.delete_if do |key, v|
        next true if /\@\w+:/ === key.to_s
        clean_value(v)
        false
      end
    when Array
      value.each { |v| clean_value(v) }
    end
  end
  
  def parse_soap_products(response)
    clean_value(response.to_hash[:get_all_products_response][:return][:item])

    products.collect do |product|
      attributes = {}
      product.__xmlele.each do |node, value|
        value = value.strip if value.is_a?(String)
        value = value.collect { |v| v.is_a?(String) ? v.strip : v } if value.is_a?(Array)
        attributes[node.name] = value
      end
      attributes['pricing'] = attributes['pricing'].prices.collect do |price|
        { :minimum => price.fromQty.to_i,
          :fixed => Money.new(0),
          :marginal => Money.new(price.price.to_f).round_cents
        }
      end
      attributes
    end
  end
  
  def merge_products(orig, new)
    new_nums = new.collect { |p| p['Web_Id'] }
    orig.find_all { |p| not new_nums.include?(p['Web_Id']) } + new
  end
  
  def parse_products
    file_name = cache_file("Lanco_SOAPparse")
    if cache_exists(file_name)
      date = File.mtime(file_name)
      @products = cache_read(file_name)
      if date < (Time.now - 24*60*60)
        date = (date - 24*60*60).strftime("%Y-%m-%d");
        puts "Getting Updated Products from #{date}"
        @products = merge_products(products, parse_soap_products(@driver.getAllChangedProducts(date)))
        cache_write(file_name, products)
      end
    else
      puts "Getting All Products"
      @products = parse_soap_products(@client.request(:getAllProducts))
      cache_write(file_name, products)
    end

    file_name = cache_file("Lanco_Images")
    @image_list = cache_read(file_name) if cache_exists(file_name)

    
    @products.each do |product|
      supplier_num = product[:web_id]
      if override = @@overrides[supplier_num]
        override.each do |prop, (old_value, new_value)|
          if product[prop] != old_value
            raise "Override old value doesn't match: #{supplier_num}: #{product[prop].inspect} != #{old_value.inspect}"
          end
          product[prop] = new_value
        end
      end
    end 
    
    process_products(@products)

    cache_write(file_name, @image_list)

#    raise "FAIL"
  end
  
  attr_reader :products
end
