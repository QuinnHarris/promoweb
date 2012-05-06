class LancoXLS < GenericImport
  def initialize
    @image_list = {}
    super "Lanco"

    @decorations = {}
  end

  def imprint_colors
    %w(340 3305 Process\ Blue Reflex\ Blue 2935 116 021 186 209 320 2597 871 Black White 877 876 281 CoolGray\ 7 476 190)
  end

  def fetch
    wf = WebFetch.new('http://www.lancopromo.com/downloads/LANCO-ProductData.zip')
    path = wf.get_path(Time.now - 5.days)
    dst_path = File.join(JOBS_DATA_ROOT,'lanco')
    out = `unzip -o #{path} -d #{dst_path}`
    list = out.scan(/inflating:\s+(.+?)\s*$/).flatten
    raise "More than one file" if list.length > 1
    list.first
  end

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

  @@fills = {
    'A' => %w(Animal\ Crackers Carmel\ Popcorn Honey\ Roasted\ Peanuts Gold\ Fish Jelly\ Beans Mini\ Pretzels Peanuts Red\ Hots Starlight\ Mints Tootsie\ Rolls),
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

    sizes = [product['imprint_area']].uniq.collect do |str|
      parse_area(str)
    end.compact
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

  def process_prices(product)
    prices = (1..6).collect do |n|
      minimum = Integer(product["Col#{n}MinQty"] || product["Col#{n}Min"])
      next nil if minimum == 0
      { :fixed => Money.new(0),
        :minimum => minimum,
        :marginal => Money.new(Float(product["Col#{n}Price"]))
      }
    end.compact
    
    cost_list = convert_pricecodes(product['PriceCode'] || '5R').zip(prices).collect do |perc, price|
      (price[:marginal] * (1.0-perc)).round_cents if price
    end.compact
    
    costs = [
      { :fixed => Money.new(0),
        :minimum => prices.first[:minimum],
        :marginal => cost_list.last,
      },
      { :minimum => (prices.last[:minimum] * 1.5).to_i
      }
    ]
    
    min = Integer(product['absoluteMin'])
    raise "min above first" if prices.first[:minimum] < min
    raise "unexpected min charge" if product['belowMinCharge'] != '$30(V)'
    if prices.first[:minimum] > 1 and prices.first[:minimum] > min
      costs.unshift({ :fixed => Money.new(24.00),
        :minimum => min,
        :marginal => cost_list.last,
      })
    end
    
    { 'prices' => prices, 'costs' => costs }
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

  def parse_products
    file_name = cache_file("Lanco_Images")
    @image_list = cache_read(file_name) if cache_exists(file_name)

    puts "Fetching Data"
    file = fetch

    puts "Reading Excel: #{file}"
    ws = Spreadsheet.open(file).worksheet(0)
    ws.use_header
        
    products = []
    sub_products = {}
    sub_products.default = []
    ws.each(1) do |row|
      data = ws.header_map.each_with_object({}) { |(k, v), h| h[k] = row[v] }
      unless row['ParentID'].blank?
        puts "Sub: #{data['ParentID'].inspect}"
        sub_products[data['ParentID']] += [data]
      else
        products << data
      end
    end

    puts "Processing"
    
    products.each do |product|
      sub = sub_products[product['ProductID']]
      common, parts = find_common_list(([product] + sub).collect { |p| p['Prod_Name'].gsub(/(?:w\/)|(?:with)/i,'') })

     
#      description = product['CleanProd_Description'].strip + "\n" + product['Order_info'].strip
#      description.gsub!('&nbsp;',' ')
#      description.gsub!(/\s*\n\s*/,"\n")

      doc = Nokogiri::HTML(product['Prod_Description'])
      description = doc.root.search('text()').collect { |n| n.text.strip }.find_all { |s| !s.empty? }.join("\n")
      
      # Replace Lanco Product ID references to our product ids
      description.scan(/\w{2,3}\d{3,4}/).each do |num|
        next unless our_id = get_id(num)
        description.gsub!(num, "<a href='#{our_id}'>#{our_id}</a>")
      end
      
#      if parts.find { |s| s.include?('A Fill')}
#        @@fills.each do |name, list|
#          description += "\n<a href='/static/fills##{name.downcase}'><strong>#{name} Fills:</strong></a>#{list.join(', ')}"
#        end
#      end
      
      product_data = {
        'supplier_num' => product['ProductID'],
        'name' => convert_name(product['Alt_Prod_Name'].empty? ? product['Prod_Name'] : product['Alt_Prod_Name']),
        'description' => description,
        'decorations' => [],
        'tags' => {
          'New' => 'New',
          'Closeout' => 'Closeout',
          'isKosher' => 'Kosher',
          'MadeInUSA' => 'MadeInUSA',
          'isEcoFriendly' => 'Eco',
        }.collect { |method, name| name if product[method] == 'YES' }.compact,
        'supplier_categories' => [[product['Category'], product['Subcategory']]],
        'package_unit_weight' => product['shipping_info(wt/100)'].is_a?(String) ? (product['shipping_info(wt/100)'].to_f / 100.0) : nil
      }

      # Lead Times
      raise "Unkown Lead: #{product['production_time']}" unless /(\d+)-(\d+) ((?:Business Days)|(?:weeks))/i === product['production_time']
      multiplier = $3.include?('weeks') ? 7 : 1
      product_data['lead_time_normal_min'] = $1.to_i * multiplier
      product_data['lead_time_normal_max'] = $2.to_i * multiplier

#      puts "Rush: #{product_data['supplier_num']} : #{product[:rushservice_id]}"
      # 0 - none
      # 1 - 3day, 1day, 2hr
      # 2 - 3day, 1day
      # 3 - 3day
      product_data['lead_time_rush'], product_data['lead_time_rush_charge'] =
        case product['rush_svc_type'].to_i
        when 1,2
          [1, 1.25]
        when 3
          [3, 1.15]
        else
          [nil, nil]
        end
      
#      product_data['image-thumb'] = product_data['image-main'] = product_data['image-large'] = HiResImageFetch.new("http://www.lancopromo.com/images/products/#{product_data['supplier_num'].downcase}/#{product_data['supplier_num'].downcase}.jpg")
            
      #puts

      image_list = get_images(product_data['supplier_num'])
      #puts "List #{product_data['supplier_num']}: #{image_list.inspect}"
      image_list = image_list.collect { |img| ImageNodeFetch.new(img, "#{image_path(product_data['supplier_num'])}#{img}") }

      used_image_list = []

      if img = image_list.find { |img| img.id == "#{product_data['supplier_num'].downcase}.jpg" }
        used_image_list << img
        product_data['images'] = [img]
      else
#        puts "NO MAIN IMAGE"
      end


      # Decorations
      product_data['decorations'] = decorations(product)

      colors = product['colors'].split(/,\s*/)
      #puts "Colors: #{colors.inspect}"
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

      puts "Var: #{(([product] + sub).collect { |p| p['ProductID'] }).zip(parts).inspect}"
      
      full_color = false
      if parts.length == 2 and parts[0].blank? and parts[1].include?('Full Color')
        parts = ['Color Print', 'Full Color']
        full_color = true
      end

      product_data['variants'] = ([product] + sub).zip(parts).collect do |prod, fill_name|
        price_data = process_prices(prod)
        properties = { 'material' => prod['Materials'] }
        properties.merge!('dimension' => parse_volume(prod['Prod_size1'])) if prod['Prod_size1']
        properties.merge!('imprint' => fill_name) if full_color
        
        vars = color_image.collect do |color, images|
#          puts "Color: #{color}  Img: #{images && images.join(', ')}"
          # For Each Variant
          { 'supplier_num' => (prod['ProductID'] + (color && "-#{color}").to_s)[0...32],
            'properties' => properties.merge('color' => color),
            'images' => images
          }.merge(price_data)
        end

        unless full_color or sub.empty?
          vars = vars.collect do |hash|
            puts "Fill Name: #{fill_name.inspect}"
            if /^(A|B|C) Fill$/ === fill_name
              letter = $1
              @@fills[letter].collect do |fill|
                hash.merge('supplier_num' => "#{hash['supplier_num'][0..12]}-#{letter}-#{fill}"[0..31],
                           'fill' => "#{letter}-#{fill}",
                           'swatch-medium' => LocalFetch.new(File.join(JOBS_DATA_ROOT, 'Lanco-Fills-Swatches'), "#{fill}.png"))
                
              end
            else
              hash.merge('fill' => fill_name)
            end
          end
        end

        vars
      end.flatten

      # All Unassociated images
      unused_image_list = image_list - used_image_list
      unless unused_image_list.empty?
        puts "UNUSED IMG: #{unused_image_list.join(', ')}"
        product_data['images'] += unused_image_list
      end
      
      add_product(product_data)
    end

    puts @decorations.keys.inspect

    cache_write(file_name, @image_list)
  end
end
