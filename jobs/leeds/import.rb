#require 'spreadsheet'
require 'net/ftp'

class LeedsXLSProducts < XLSFile
  @@color_map =
  { '' => '',
    "Espresso"=>"ES",
    "Plasma Ball"=>"BB",
    "Yellow"=>"YW",
    "White"=>"WH",
    "Charcoal"=>"CH",
    "Olive"=>"OL",
    "Chestnut"=>"CT",
    "Blue"=>"BL",
    "Bk On Bk"=>"RBB",
    "Graphite"=>"GA", 
    "Silver"=>"SL",
    "Grey"=>"GY",
    "Orange"=>"OR",
    "Natural"=>"NAT",
    "Gold"=>"GL",
    "Midnight Chrome"=>"SL",
    "Navy"=>"NY",
    "Royal"=>"RL",
    "Multicolor"=>"MT",
    "Multicol"=>"MT",
    "Taupe"=>"TP",
    "Gray"=>"GY",
    "Poncho"=>"WH",
    "Red"=>"RD",
    "Purple"=>"PP",
    "Aquarium"=>"BK",
    "Smoke"=>"SM",
    "Lime"=>"LM",
    "Green"=>"GR",
    "Mahogany"=>"CC",
    "Mahogny"=>"CC",
    "Titanium"=>"TI",
    "Clear"=>"CL", 
    "Black"=>"BK",
    "Wood"=>"WD",
    "Brown"=>"BR",
    "Pink" => 'PK',
    "Translucent blue" => "TBL",
    "Translucent green" => "TGR",
    "Translucent purple" => "TPR",
    "Translucent red" => "TRD",
    "White with black" => "WH-BK",
    "white with black" => "WH-BK",
    "White with blue" => "WH-BL",
    "white with blue" => "WH-BL",
    "White with green" => "WH-GR",
    "white with green" => "WH-GR", }
  
  def initialize(file)
    super file

    # Kludge for FifthCoPriceUSD
    @header = @header.collect { |s| /ColPriceUS$/i === s ? "#{s}D" : s }
  end
  
  def parse_row(row)
    product_data = {}
    
    supplier_num = get(row, 'ItemNumber').to_s.strip
    return nil if supplier_num.empty?
    return nil if supplier_num == '1225-69' # Patent BS
    raise "Bad Item: #{supplier_num}" unless /(\d+-\d+)(\w*)/ =~ supplier_num
    product_data['supplier_num'] = $1
    
    product_data['name'] = get(row, 'ProductName').to_s.strip

    product_data['lead_time_normal_min'] = 3
    product_data['lead_time_normal_max'] = 5
    product_data['lead_time_rush'] = 1
    
    product_data['supplier_categories'] = [[get(row, 'Category').to_s, get(row, 'SubCategory').to_s]]

    tags = []
    tags << 'New' if get(row, 'NewItem') == 'NEW'
    tags << 'Eco' if get(row, 'Category') == 'EcoSmart'
    product_data['tags'] = tags
    
    { 'GIFTBOXED_LENGTH' => 'package_length',
      'GIFTBOXED_WIDTH' => 'package_width',
      'GIFTBOXED_Height' => 'package_height',
      'CartonWeight' => 'package_weight' }.each do |src, dst|
      node = get(row, src)
      product_data[dst] = node && node.to_f
    end
    product_data['package_units'] = get(row, 'CartonPackQTY').to_i
    product_data['package_unit_weight'] = 0.0
    
    # \s*(?:\342\200\242)|(?:\302\267)|
    product_data['description'] = get(row, 'ItemDescription').to_s.split(/[\r\n]+|(?:\. )\s*/).collect do |line|
      line.strip
      next nil if line.empty?
      [??,?!,?.].include?(line[-1]) ? line : "#{line}." 
    end.compact.join("\n")
    
    # Images
#    product_data['image-thumb'] = TransformImageFetch.new("http://media.leedsworld.com/msfiles/small/#{product_data['supplier_num']}.jpg")
#    path = "http://media.leedsworld.com/ms/?/large/#{product_data['supplier_num']}/en"
#    product_data['image-main'] = TransformImageFetch.new(path)
#    product_data['image-large'] = CopyImageFetch.new(path)
    
    maximum = nil
    prices = %w(First Second Third Fourth Fifth).collect do |name|
      minimum = get(row, "#{name}ColMinQty").to_i
      raise "Last Max doesn't match this min: #{maximum} + 1 != #{minimum} for #{supplier_num}" if maximum and maximum + 1 != minimum
      maximum = get(row, "#{name}ColMaxQTY")
      maximum = maximum && maximum.to_i
      marginal = get(row, "#{name}ColPriceUSD").to_f
      
      { :minimum => minimum,
        :fixed => Money.new(0),
        :marginal => Money.new(marginal)
      }
    end
    
    costs = [
        { :fixed => Money.new(36.00),
          :minimum => ((prices.first[:minimum] + 0.5) / 2).to_i,
          :marginal => (prices[-1][:marginal] * 0.6).round_cents
        },
        { :fixed => Money.new(0),
          :minimum => prices.first[:minimum],
          :marginal => (prices[-1][:marginal] * 0.6).round_cents
        }]
        
#    costs += prices[-2..-1].collect do |price|
#      { :fixed => Money.new(0),
#        :minimum => price[:minimum],
#        :marginal => price[:marginal] * 0.6
#      }
#    end
        
    costs << { :minimum => (prices.last[:minimum] * 1.5).to_i }
    
    dimension = {}
    { 'ItemLength'=> 'length', 
      'ItemWidth' => 'width',
      'ItemHeight' => 'height' }.each do |src, dst|
      num = get(row, src).to_s.gsub('\'','').to_f
      dimension[dst] = num unless num == 0.0
    end
    
    material = get(row, 'Material').to_s
    
    colors = get(row, 'Color').to_s.split(/\s*(?:(?:\,|(?:or)|(?:and)|\&)\s*)+/).uniq
#    puts "Colors: #{get(row, 'Colors').to_s.inspect} => #{colors.inspect}"
    colors = [''] if colors.empty?
    product_data['variants'] = colors.collect do |color|
      color = color.strip.capitalize
      postfix = @@color_map[color]
      unless postfix
        puts "#{product_data['supplier_num']}: #{color}" 
        postfix = color[0...8]
      end
      { 'supplier_num' => "#{product_data['supplier_num']}#{postfix}",
        'color' => color,
        'material' => material,
        'dimension' => dimension,
        'prices' => prices,
        'costs' => costs,
      }
    end
    
    product_data
  end
  
  def parse
    list = []
    @worksheet.each(1) do |row|
      data = parse_row(row)
      list << data if data
    end
    list
  end
end

class LeedsXLSDecorations < XLSFile
  @@decoration_replace = {
    'Silkscreen' => ['Screen Print',3],
    'ColorPrint' => ['Screen Print',3],
    'Drinkware' => ['Screen Print',3],
    'Transfer' => ['Screen Print',3],
    'Watch Printing' => ['Screen Print', 3],

    'PhotoReal' => ['Photo Transfer',3],
    'Deboss' => ['Deboss',1],
    'Deboss Initials' => ['x', 1],
    'Laser Etching' => ['Laser Engrave',1],
    'Laser Etching Name' => ['x',1],
    'Laser Etching Initials' => ['x',1],
    'Laser Etch With Outline' => ['x',1],
    'Laser Outline Only' => ['x',1],
    'Name- personalization' => ['x',1],

    'Embroidery' => ['Embroidery', 10000],
    'Embroidery Initials' => ['x', 1],
    'Embroidery Name' => ['x', 1],

    'Custom Dome' => ['x', 1],
    'Epoxy Dome' => ['Dome', 1],
    'Epoxy Dome Pers' => ['x', 1],

    'Color Fill' => ['x', 1],
    'Color Fill Initials' => ['x', 1],

    'Color Stamp' => ['Stamp', 1],
    'Color Stamp DB' => ['x', 1],
    'Color Stamp Name' => ['x', 1],
    'Color Stamp Initials' => ['x', 1],

    'Oxidize' => ['x', 1],

    'Sticker' => ['x', 1],

    'Upload' => ['x', 1],

    'Metal' => ['x', 1],

    '3d' => ['x', 1],
  }
  
  @@repstats = {}
  @@repstats.default = 0
  
  def initialize(file)
    super file

    # Kludge for FifthCoPriceUSD
    @header = @header.collect { |s| s.downcase }
  end

  def dec_replace(name)
    ret = @@decoration_replace[name]
    @@repstats[name] += 1 unless ret
    puts name unless ret
    ret = [name,1] unless ret
    ret
  end
  
  def parse
    decoration_data = {}
    decoration_data.default = []
    decoration_onecolor = {}

    # supplier_num => technique => location : limit
    @worksheet.each(1) do |row|
      supplier_num = get(row, 'ItemNumber').to_s
      next if supplier_num.empty?

      technique = get(row, 'Method').to_s

      location = get(row, 'Location').to_s.split(' ').collect do |w| 
        %w(ON FROM BETWEEN DOWN).index(w) ? w.downcase : w.capitalize
      end.join(' ')

      if location.downcase.index("one color")
        decoration_onecolor[[supplier_num, technique]] = true
        next
      end

      decoration_entry = {
        'technique' => technique,
        'location' => location,
        'width' => get(row, 'Length').to_f,
        'height' => get(row, 'Height').to_f
      }

      decoration_data[supplier_num] += [decoration_entry]
    end
    

    decoration_final = {}
    decoration_data.each do |supplier_num, decoration_entries|
      raise "Bad Item: #{supplier_num}" unless /(\d+-\d+)(\w*)/ =~ supplier_num
      prefix, postfix = $1, $2

      entries = []
      decoration_entries.each do |entry|
        technique, limit = dec_replace(entry['technique'])
        if decoration_onecolor[[supplier_num, entry['technique']]]
          limit = 1
        end
        entry['technique'] = technique

        merge = entries.find do |existing|
          unless entry.find { |k, v| existing[k] != v }
            existing['limit'] = [existing['limit'], limit].max
            true
          else
            false
          end
        end
        
        unless merge
          entry['limit'] = limit
          entries << entry
        end
      end

      if decoration_final[prefix]
        if decoration_final[prefix] != entries
          puts "Mismatch: #{supplier_num}"
        end
      else
        decoration_final[prefix] = entries
      end
    end
  
    decoration_final
  end
end

class LeedsXLS < GenericImport
  def initialize
    @prod_files = %w(USDcatalog USDMemorycatalog).collect do |name|
      WebFetch.new("http://media.leedsworld.com/ms/?/excel/#{name}/EN").get_path(Time.now-24*60*60)
    end
    @dec_file = WebFetch.new('http://media.leedsworld.com/ms/?/excel/WebDocrationMethodByItem/EN').get_path(Time.now-24*60*60)
    @src_files = @prod_files + [@dec_file]
    super "Leeds"
  end
  
  def image_list
    cache_marshal("#{@supplier_record.name}_imagelist") do
      puts "Fetching Image List"
      ftp = Net::FTP.new('images.leedsworld.com')
      ftp.login
      files = ftp.nlst
      products = {}
      products.default = []
      files.each do |file|
        next unless file =~ /^(\d+-\d+)(\w*)\.tif$/
        products[$1] += [file]
      end
      products.default = nil
      products
    end
  end
  
  def parse_products
    puts "Loading Decorations"
    decoration_data = LeedsXLSDecorations.new(@dec_file).parse
    image_data = image_list

    products = {}
    
    @prod_files.each do |file|
      puts "Loading #{file}"
      no_decorations = []
      LeedsXLSProducts.new(file).parse.each do |product_data|
        supplier_num = product_data['supplier_num']    
        if product_exist = products[supplier_num]
          puts "Match: #{supplier_num}"
          (product_data.keys + product_exist.keys).uniq.each do |k|
            next if product_data[k] == product_exist[k]
            case k
            when 'supplier_categories'
              product_exist['supplier_categories'] = (product_exist['supplier_categories'] + product_data['supplier_categories']).uniq
              
            when 'tags'
              product_exist['tags'] ||= product_data['tags']

            else
              puts "  #{k}: #{product_exist[k].inspect} => #{product_data[k].inspect}"
            end
          end
        else
          products[supplier_num] = product_data
        end
      end
    end


    no_decorations = []
    products.values.each do |product_data|
      supplier_num = product_data['supplier_num']
            
      unless decorations = decoration_data[supplier_num]
        no_decorations << supplier_num
      end
      product_data['decorations'] = (decorations ? decorations : []) + [{
                                                                          'technique' => 'None',
                                                                          'location' => ''
                                                                        }]
      unless images = image_data[supplier_num] and images.first
        puts "No Image: #{supplier_num}"
        # Revert to media files instead of high res tiff
        product_data['image-thumb'] = TransformImageFetch.new("http://media.leedsworld.com/msfiles/small/#{product_data['supplier_num']}.jpg")
        path = "http://media.leedsworld.com/ms/?/large/#{product_data['supplier_num']}/en"
        product_data['image-main'] = TransformImageFetch.new(path)
        product_data['image-large'] = CopyImageFetch.new(path)
        #next
      else
        product_data['image-thumb'] = product_data['image-main'] = product_data['image-large'] = HiResImageFetch.new("ftp://images.leedsworld.com/#{images.first}")
      end
      add_product(product_data)
      
    end

    puts "Missing Decorations: #{no_decorations.join(', ')}"
  end
end
