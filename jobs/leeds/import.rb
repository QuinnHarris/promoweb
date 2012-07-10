# -*- coding: utf-8 -*-

class LeedsXLSDecorations

end

class PolyXLS < GenericImport  
  cattr_reader :color_map
  @@color_map =
  { '' => '',
    'limeágreen' => 'LGR', #Kludge for SM-3235
    'processáblue' => 'NEBL',
    'amthyst' => 'AM',
    'aquarium' => 'BK',
    'bk on bk' => 'RBB',
    'black' => 'BK',
    'black top with clear base' => 'BK',
    'black with silver trim' => 'SIBK', # KK-640
    'black/red' => 'BKR',
    'black pin stripe' => 'BKP', # 2050-14
    'blue' => 'BL',
    'blue/black' => 'BLBK',
    'blue with silver trim' => 'SBL', # KK-640
    'brown' => 'BR',
    'burgundy' => 'BU',
    'camouflage' => 'CA',
    'component' => 'CM', # 1030-49
    'copper' => 'CO',
    'charcoal' => 'CH',
    'chestnut' => 'CT',
    'clear' => 'CL',
    'cream' => 'CR',
    'dark red' => 'RE',
    'emerald' => 'EM',
    'espresso' => 'ES',
    'frosted orange' => 'FOR',
    'frosted red' => 'FRE',
    'gold' => 'GL',
    'graphite' => 'GA',
    'gray' => 'GY',
    'gray granite' => 'GG',
    'green' => 'GR',
    'dark green' => 'DGR',
    'green with silver trim' => 'SIGR', # KK-640
    'kelly green' => 'KGR', # SM-3122
    'grey' => 'GY',
    'gunmetal' => 'GM',
    'hunter green' => 'HG',
    'iron' => 'IN',
    'light blue' => ['LBL', 'LB'],
    'lime' => 'LM',
    'lime green' => 'LGR',
    'mahogany' => 'CC',
    'mahogny' => 'CC',
    'maroon' => 'MA',
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
    'pearlescent neon orange' => 'NOR', # KK-640
    'pearlescent neon yellow' => 'NY', # KK-640
    'pearlescent neon green' => 'NG', # KK-640
    'pearlescent neon pink' => 'NP', # KK-640
    'pink' => 'PK',
    'plasma ball' => 'BB',
    'poncho' => 'WH',
    'purple' => 'PP',
    'quartz' => 'QZ',
    'red' => ['RE', 'RD'],
    'red with silver trim' => 'SIRE', # KK-640
    'reflective triangle' => 'RE',
    'reflex blue' => 'REBL',
    'royal' => 'RY',
    'royal blue' => 'RBL',
    'ruby' => 'RU',
    'rust' => 'RS',
    'sapphire' => 'SA',
    'silver' => ['SI', 'S'],
    'silver barrel' => 'SI',
    'silver with black trim' => 'SIBK',
    'silver with black grip' => 'SIBK', # KK-930
    'silver with blue trim' => 'SIBL',
    'silver with green trim' => 'SIGR',
    'silver with red trim' => 'SIRE',
    'silver with frosted black grip' => 'SBK',
    'silver with frosted blue grip' => 'SBL',
    'silver with frosted green grip' => 'SGR',
    'silver with frosted orange grip' => 'SOR',
    'silver with frosted red grip' => 'SRE',
    'silver with green grip' => 'SGR',
    'silver with black lower barrel' => 'SIBK', # KK-955
    'silver with blue lower barrel' => 'SIBL', # KK-955
    'silver with red strap' => 'RE',
    'silver/black' => 'SIBK',
    'silver/blue' => 'SIBL',
    'silver/green' => 'SIGR',
    'silver/red' => 'SIRE',
    'smoke' => 'SM',
    'stainless steel' => 'SS',
    'strawberry granite' => 'SG',
    'solid blue' => 'SBL',
    'solid black' => 'SBK', # KK-640
    'taupe' => 'TP',
    'teal' => 'TE',
    'titanium' => 'TI',
    'translucent black' => 'TBK',
    'translucent blue' => 'TBL',
    'translucent green' => 'TGR',
    'translucent light blue' => 'TLBL',
    'translucent orange' => 'TOR',
    'translucent pink' => 'TPK',
    'translucent purple' => 'TPR',
    'translucent purple' => 'TPU',
    'translucent red' => 'TRE',
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
    'turquoise' => 'TQ',
    'white' => 'WH',
    'white barrel' => 'W',
    'white top with clear base' => 'WH',
    'white with black' => 'WH-BK',
    'white with black trim' => 'WBK', # KK-640
    'white with green trim' => 'WGR', # KK-640
    'white with red trim' => 'WRE', # KK-640
    'white with blue trim' => 'WBL', # KK-640
    'white with orange trim' => 'WOR', # KK-640
    'white with yellow trim' => 'WYE', # KK-640
    'white with blue' => 'WH-BL',
    'white with green' => 'WH-GR',
    'white with translucent red trim' => 'WRE',
    'white/blue' => 'WBL',
    'white/red' => 'WRE',
    'wood' => 'WD',
    'yellow' => ['YE', 'YW'],
     }
  
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
        product_data[dst] = row[src].to_f unless row[src].to_f == 0.0
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
      
      colors = row['Color'].to_s.split(/\s*(?:(?:\,|(?:\sor\s)|(?:\sand\s)|\&)\s*)+/).uniq
      colors = [''] if colors.empty?

      color_image_map, color_num_map = match_colors(product_data['supplier_num'], colors)
      puts "ColorMap: #{product_data['supplier_num']} #{color_image_map.inspect} #{color_num_map.inspect}"
      product_data['images'] = color_image_map[nil]

      product_data['variants'] = colors.collect do |color|
        postfix = color_num_map[color] #[@@color_map[color.downcase]].flatten.first
        unless postfix
          postfix = color.split(/ |\//).collect { |c| [@@color_map[c.downcase]].flatten.first }.join
          puts "NoPost: #{product_data['supplier_num']}: #{color} : #{postfix}"
#          postfix = color[0...8]
        end
        { 'supplier_num' => "#{product_data['supplier_num']}#{postfix}",
          'color' => color.strip.capitalize,
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
  
  def parse_products
    @image_list = get_ftp_images(@image_url) do |path, file|
      if /^((?:\d+|[A-Z]{2})-\d+)([A-Z]*).*\.(?:(?:tif)|(?:jpg))$/i === file
        product, variant = $1, $2
        tag = nil
        case suffix
        when /^\w+_B/
          tag = 'blank'
        when /^\w+_D/
          tag = 'decorated'
        end
        
        [file, product, variant, tag]
      end
    end

    # Remove jpg if tif equivelent
    @image_list.each do |num, list|
      keeps = list.collect do |path, file, var_id|
        name, ext = file.split('.')
        ext.downcase == 'tif' ? name.downcase : nil
      end.compact
      list.delete_if do |path, file, var_id|
        name, ext = file.split('.')
        next false unless ext.downcase == 'jpg'
        keeps.include?(name.downcase)
      end
    end

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
    @dec_file = WebFetch.new('http://media.leedsworld.com/msfiles/downloads/WebDecorationMethodByItem.xls').get_path(Time.now-24*60*60)
    @src_files = @prod_files + [@dec_file]
    @image_url = 'images.leedsworld.com'
    super "Leeds"
  end
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
