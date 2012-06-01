require 'net/ftp'

class LeedsXLSDecorations

end

class PolyXLS < GenericImport  
  @@color_map =
  { '' => '',
    'aquarium' => 'BK',
    'bk on bk' => 'RBB',
    'black' => 'BK',
    'black top with clear base' => 'BK',
    'black/red' => 'BKR',
    'blue' => 'BL',
    'blue/black' => 'BLBK',
    'brown' => 'BR',
    'camouflage' => 'CA',
    'charcoal' => 'CH',
    'chestnut' => 'CT',
    'clear' => 'CL',
    'dark red' => 'RE',
    'espresso' => 'ES',
    'frosted orange' => 'FOR',
    'frosted red' => 'FRE',
    'gold' => 'GL',
    'graphite' => 'GA',
    'gray' => 'GY',
    'gray granite' => 'GG',
    'green' => 'GR',
    'grey' => 'GY',
    'hunter green' => 'HG',
    'iron' => 'IN',
    'light blue' => 'LBL',
    'lime' => 'LM',
    'lime green' => 'LGR',
    'mahogany' => 'CC',
    'mahogny' => 'CC',
    'matte silver' => 'SI',
    'midnight chrome' => 'SL',
    'multicol' => 'MT',
    'multicolor' => 'MT',
    'natural' => 'NT',
    'navy' => 'NY',
    'navy blue' => 'NBL',
    'neon green' => 'NG',
    'ni' => 'NI',
    'olive' => 'OL',
    'orange' => 'OR',
    'pink' => 'PK',
    'plasma ball' => 'BB',
    'poncho' => 'WH',
    'purple' => 'PP',
    'red' => 'RD',
    'reflective triangle' => 'RE',
    'reflex blue' => 'REBL',
    'royal' => 'RY',
    'royal blue' => 'RBL',
    'silver' => 'SL',
    'silver barrel' => 'SI',
    'silver with black trim' => 'SIBK',
    'silver with blue trim' => 'SIBL',
    'silver with green trim' => 'SIGR',
    'silver with frosted black grip' => 'SBK',
    'silver with frosted blue grip' => 'SBL',
    'silver with frosted green grip' => 'SGR',
    'silver with frosted orange grip' => 'SOR',
    'silver with frosted red grip' => 'SRE',
    'silver with red strap' => 'RE',
    'silver/black' => 'SIBK',
    'silver/blue' => 'SIBL',
    'silver/green' => 'SIGR',
    'silver/red' => 'SIRE',
    'smoke' => 'SM',
    'stainless steel' => 'SS',
    'strawberry granite' => 'SG',
    'taupe' => 'TP',
    'titanium' => 'TI',
    'translucent black' => 'TBK',
    'translucent blue' => 'TBL',
    'translucent green' => 'TGR',
    'translucent light blue' => 'TLBL',
    'translucent orange' => 'TOR',
    'translucent pink' => 'TPK',
    'translucent purple' => 'TPR',
    'translucent purple' => 'TPU',
    'translucent red' => 'TRD',
    'translucent royal blue' => 'TRBL',
    'translucent yellow' => 'TYE',
    'transparent aqua blue' => 'TABL',
    'transparent black' => 'TBK',
    'transparent blue' => 'TBL',
    'transparent blue top/base' => 'TLB',
    'transparent dark blue' => 'TDBL',
    'transparent green' => 'TGR',
    'transparent green top/base' => 'TGR',
    'transparent orange' => 'TOR',
    'transparent pink' => 'TPK',
    'transparent purple' => 'TPU',
    'transparent red' => 'TRE',
    'transparent yellow' => 'TYE',
    'white' => 'WH',
    'white barrel' => 'W',
    'white top with clear base' => 'WH',
    'white with black' => 'WH-BK',
    'white with blue' => 'WH-BL',
    'white with green' => 'WH-GR',
    'white with translucent red trim' => 'WRE',
    'white/blue' => 'WBL',
    'white/red' => 'WRE',
    'wood' => 'WD',
    'yellow' => 'YW',
     }

  def match_colors(supplier_num, colors)
    result = {}
    result.default = []

    mapped = colors.collect { |c| @@color_map[c.downcase] }

    (@image_list[supplier_num] || []).each do |img, suf|
      img = ImageNodeFetch.new(img, image_path(img))
      if suf.empty?
        result[nil] += [img]
        next
      end

      if i = mapped.index(suf)
        result[colors[i]] += [img]
        next
      end

      reg = Regexp.new(suf.split('').collect { |s| [s, '.*'] }.flatten[0..-2].join, Regexp::IGNORECASE)
      list = colors.find_all do |color|
        (reg === color)
      end

      if list.length == 1
        result[list.first] += [img]
        next
      end

      if list.length > 1
        puts "Multiple Match: #{supplier_num} #{img} #{suf} #{list.inspect}"
      end

      result[nil] += [img]
    end

    result
  end
  
  def parse_catalog(file)
    list = []

    ws = Spreadsheet.open(file).worksheet(0)
    ws.use_header

    ws.each(1) do |row|
      next unless row['ItemNumber']

      product_data = {
        'supplier_num' => row['ItemNumber'].strip,
        'name' => row['ProductName'].strip,
        'lead_time_normal_min' => 3,
        'lead_time_normal_max' => 5,
        'lead_time_rush' => 1,
        'supplier_categories' => [[row['Category'], row['SubCategory']]]
      }
    
      tags = []
      tags << 'New' if row['NewItem'] == 'NEW'
      tags << 'Eco' if row['Category'] == 'EcoSmart'
      product_data['tags'] = tags
      
      { 'GIFTBOXED_LENGTH' => 'package_length',
        'GIFTBOXED_WIDTH' => 'package_width',
        'GIFTBOXED_Height' => 'package_height',
        'CartonWeight' => 'package_weight' }.each do |src, dst|
        product_data[dst] = row[src].to_f
      end
      product_data.merge!('package_units' => row['CartonPackQTY'].to_i,
                          'package_unit_weight' => 0.0)
    
      product_data['description'] = row['ItemDescription'].to_s.split(/[\r\n]+|(?:\. )\s*/).collect do |line|
        line.strip
        next nil if line.empty?
        [??,?!,?.].include?(line[-1]) ? line : "#{line}." 
      end.compact.join("\n")
       
      maximum = nil
      prices = %w(First Second Third Fourth Fifth).collect do |name|
        minimum = row["#{name}ColMinQty"].to_i
        raise "Last Max doesn't match this min: #{maximum} + 1 != #{minimum} for #{supplier_num}" if maximum and maximum + 1 != minimum
        maximum = row["#{name}ColMaxQty"]
        maximum = maximum && maximum.to_i
        
        { :minimum => minimum,
          :fixed => Money.new(0),
          :marginal => Money.new(row["#{name}ColPriceUSD"].to_f)
        }
      end
    
      costs = [
               { :fixed => Money.new(40.00),
                 :minimum => ((prices.first[:minimum] + 0.5) / 2).to_i,
                 :marginal => (prices[-1][:marginal] * 0.6).round_cents
               },
               { :fixed => Money.new(0),
                 :minimum => prices.first[:minimum],
                 :marginal => (prices[-1][:marginal] * 0.6).round_cents
               }]
        
      costs << { :minimum => (prices.last[:minimum] * 1.5).to_i }
      
      dimension = {}
      { 'ItemLength'=> 'length', 
        'ItemWidth' => 'width',
        'ItemHeight' => 'height' }.each do |src, dst|
        num = row[src].to_s.gsub('\'','').to_f
        dimension[dst] = num unless num == 0.0
      end
      
      material = row['Material'].to_s
      
      colors = row['Color'].to_s.split(/\s*(?:(?:\,|(?:or)|(?:and)|\&)\s*)+/).uniq
      colors = [''] if colors.empty?

      color_image_map = match_colors(product_data['supplier_num'], colors)
      puts "ColorMap: #{product_data['supplier_num']} #{color_image_map.inspect}"
      product_data['images'] = color_image_map[nil]

      product_data['variants'] = colors.collect do |color|
        color = color.strip.capitalize
        postfix = @@color_map[color.downcase]
        unless postfix
          puts "NoPost: #{product_data['supplier_num']}: #{color}" 
          postfix = color[0...8]
        end
        { 'supplier_num' => "#{product_data['supplier_num']}#{postfix}",
          'color' => color,
          'material' => material,
          'dimension' => dimension,
          'prices' => prices,
          'costs' => costs,
          'images' => color_image_map[color]
        }
      end
    
      list << product_data
    end
    list
  end


  # Decoration XLS file
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

    
    # Bullet
    'Silkscreened' => ['Screen Print',3],
    'Laser Engraved' => ['Laser Engrave',1],
  }
  
  def dec_replace(name)
    ret = @@decoration_replace[name]
    puts name unless ret
    ret = [name,1] unless ret
    ret
  end
  
  def parse_decorations(file)
    puts "Loading Decorations"

    decoration_data = {}
    decoration_data.default = []
    decoration_onecolor = {}

    ws = Spreadsheet.open(file).worksheet(0)
    ws.use_header

    # supplier_num => technique => location : limit
    ws.each(1) do |row|
      supplier_num = row['ItemNumber'].to_s
      next if supplier_num.empty?

      technique = row['Method'].to_s

      location = row['Location'].to_s.split(' ').collect do |w| 
        %w(ON FROM BETWEEN DOWN).index(w) ? w.downcase : w.capitalize
      end.join(' ')

      if location.downcase.index("one color")
        decoration_onecolor[[supplier_num, technique]] = true
        next
      end

      decoration_entry = {
        'technique' => technique,
        'location' => location,
        'width' => row['Length'].to_f,
        'height' => row['Height'].to_f
      }

      decoration_data[supplier_num] += [decoration_entry]
    end
    

    decoration_final = {}
    decoration_data.each do |supplier_num, decoration_entries|
      raise "Bad Item: #{supplier_num}" unless /^((?:\d+|[A-Z]{2})-\d+)(\w*)/ =~ supplier_num
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

  def image_path(image); "ftp://#{@image_url}/#{image}"; end

  def get_images
    cache_marshal("#{@supplier_record.name}_imagelist") do
      puts "Fetching Image List"
      ftp = Net::FTP.new(@image_url)
      ftp.login
      files = ftp.nlst
      products = {}
      products.default = []
      files.each do |file|
        unless file =~ /^((?:\d+|[A-Z]{2})-\d+)([A-Z]*).*\.(?:(?:tif)|(?:jpg))$/i
          puts "Unknown File: #{file}"
          next
        end
        raise "nil one" unless $1
        products[$1] += [[file, $2]]
      end
      products.default = nil
      
      # Remove jpg if tif equivelent
      products.each do |num, list|
        keeps = list.collect do |f, suf|
          name, ext = f.split('.')
          ext.downcase == 'tif' ? name.downcase : nil
        end.compact
        list.delete_if do |f, suf|
          name, ext = f.split('.')
          next false unless ext.downcase == 'jpg'
          keeps.include?(name.downcase)
        end
      end

      products
    end
  end
  
  def parse_products
    @image_list = get_images
    decoration_data = parse_decorations(@dec_file)

    products = {}
    
    @prod_files.each do |file|
      puts "Loading #{file}"
      no_decorations = []
      parse_catalog(file).each do |product_data|
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
              puts "  Mismatch:"
              product_exist.each do |key, v|
                next if product_data[key] == v
                puts "   #{key} #{v.inspect} => #{product_data[key].inspect}"
              end
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
      product_data['decorations'] = (decorations ? decorations : []) +
        [{
           'technique' => 'None',
           'location' => ''
         }]

      add_product(product_data)      
    end

    puts "Missing Decorations: #{no_decorations.join(', ')}"
  end
end


class LeedsXLS < PolyXLS
  def initialize
    puts "Stating Fetch for Leeds"
    @prod_files = %w(USDcatalog USDMemorycatalog).collect do |name|
      WebFetch.new("http://media.leedsworld.com/ms/?/excel/#{name}/EN").get_path(Time.now-24*60*60)
    end
    @dec_file = WebFetch.new('http://media.leedsworld.com/ms/?/excel/WebDocrationMethodByItem/EN').get_path(Time.now-24*60*60)
    @src_files = @prod_files + [@dec_file]
    @image_url = 'images.leedsworld.com'
    super "Leeds"
  end

#  def image_path(image)
#    str = "http://media.leedsworld.com/ms/?/large/#{image.split('.').first}/en"
#    puts "Image: #{str}"
#    str
#  end
end

class BulletXLS < PolyXLS
  def initialize
    @prod_files = [File.join(JOBS_DATA_ROOT, 'Bullet/catalog.xls')]
    @dec_file = File.join(JOBS_DATA_ROOT, 'Bullet/WebDecorationMethodByItem.xls')
    @src_files = @prod_files + [@dec_file]
    @image_url = 'images.bulletline.com'
    super "Bullet Line"
  end
end
