require 'spreadsheet'
require 'net/ftp'

class BulletLineXLS < XLSFile

end


class BulletLine < GenericImport
  @@color_map =
  { #'' => '',
    "Espresso"=>"ES",
    "Plasma Ball"=>"BB",
    "Yellow"=>"YW",
    "White"=>"W",
    "Charcoal"=>"CH",
    "Olive"=>"OL",
    "Chestnut"=>"CT",
    "Blue"=>"BL",
    "Bk On Bk"=>"RBB",
    "Graphite"=>"GA", 
    "Silver"=>"SI",
    "Matte Silver"=>"SI",
    "Silver Barrel"=>"SI",
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
    "Red"=>"RE",
    "Dark Red" => "RE",
    "Purple"=>"PP",
    "Aquarium"=>"BK",
    "Smoke"=>"SM",
    "Lime"=>"LM",
    "Lime Green" => "LGR",
    "Green"=>"GR",
    "Mahogany"=>"CC",
    "Mahogny"=>"CC",
    "Titanium"=>"TI",
    "Clear"=>"CL", 
    "Black"=>"BK",
    "Wood"=>"WD",
    "Brown"=>"BR",
    "Pink" => 'PK',
    "Translucent Blue" => "FBL",
    "Frosted Orange" => "FOR",
    "Frosted Red" => "FRE",
    "Silver/Black" => "SIBK",
    "Silver/Blue" => "SIBL",
    "Silver/Green" => "SIGR",
    "Silver/Red" => "SIRE",
    "White/Blue" => "WBL",
    "White/Red" => "WRE",
#    "Solid Black" => "SBK",
#    "Solid Blue" => "SBL",
    "White Barrel" => "W",
    "Translucent Blue" => "TBL",
    "Translucent Green" => "TGR",
#    "Translucent purple" => "TPR",
    "Translucent Red" => "TRD",
    "Translucent Yellow" => "TYE",
    "Translucent Black" => "TBK",
    "Translucent Orange" => "TOR",
    "Translucent Purple" => "TPU",
    "Translucent Light Blue" => "TLBL",
    "Translucent Pink" => "TPK",
    "Translucent Royal Blue" => "TRBL",
    "Stainless Steel" => "SS",

    "Transparent Blue" => "TBL",
    "Transparent Green" => "TGR",
    "Transparent Orange" => "TOR",
    "Transparent Red" => "TRE",
    "Transparent Black" => "TBK",
    "Transparent Pink" => "TPK",
    "Transparent Purple" => "TPU",
    "Transparent Yellow" => "TYE",
    "Transparent Aqua Blue" => "TABL",
    "Transparent Dark Blue" => "TDBL",
    "Reflective Triangle" => "RE",
    "Gray Granite" => "GG",
    "Strawberry Granite" => "SG",
    "Light Blue" => "LBL",
    "Neon Green" => "NG",
    "Reflex Blue" => "REBL",
    "Camouflage" => "CA",
    "Navy Blue" => "NBL",
    "Royal Blue" => "RBL",
    "Silver with Frosted Black Grip" => "SBK", # KK-930
    "Silver with Frosted Blue Grip" => "SBL",  # KK-930
    "Silver with Frosted Green Grip" => "SGR", # KK-930
    "Silver with Frosted Orange Grip" => "SOR",# KK-930
    "Silver with Frosted Red Grip" => "SRE",   # KK-930
    "Silver with Red Strap" => "RE", # SM-2382

    "Black Top with Clear Base" => "BK",       # SM-3220
    "Transparent Blue Top/Base" => "TLB",      # SM-3220
    "Transparent Green Top/Base" => "TGR",     # SM-3220
    "White Top with Clear Base" => "WH",       # SM-3220
    "White with Translucent Red Trim" => "WRE",# SM-3220
  }

  def initialize(file)
    @data = BulletLineXLS.new(File.join(JOBS_DATA_ROOT, file))
    super "Bullet Line"
  end

  @@decoration_replace = {
    'silkscreened' => ['Screen Print', 6],
    'laser engraved' => ['Laser Engrave', 1],
    'debossed' => ['Deboss', 2],
    'heat transferred' => ['Photo Transfer', nil],
  }
    
  def parse_products
    @data.worksheet.each(1) do |row|
      product = {
        'lead_time_normal_min' => 3,
        'lead_time_normal_max' => 5,
        'lead_time_rush' => 1,
      }

      { 'ItemNo' => 'supplier_num',
        'ItemName' => 'name' }.each do |col_name, prop|
        product[prop] = @data.get(row, col_name)
      end

#      next if ['SM-3220', 'SM-3450'].include?(product['supplier_num'])

      product['description'] = %w(CatalogDescription Disclaimers).collect { |n| s = @data.get(row, n); s && s.split(/\.\s*/) }.flatten.compact.join(".\n")     

      product['supplier_categories'] = [[@data.get(row, 'Category').strip, @data.get(row, 'SubCategory').strip]]

      product['package_weight'] = @data.get(row, 'WeightCase').to_i

      material = @data.get(row, 'Material')


      # Tags
      tags = []
      tags << 'New' if @data.get(row, 'ItemStatus') == 'New'
      tags << 'MadeInUSA' if @data.get(row, 'Icon_MadeInUSA') == 'Yes'
      tags << 'Eco' if @data.get(row, 'Icon_Recycled') == 'Yes'


      # Pricing
      last_minimum = nil
      prices = (1..5).collect do |num|
        minimum = Integer(@data.get(row, "PriceQtyCol#{num}"))
        minimum = 1 if minimum < 1
        raise "Last Max doesn't match this min: #{maximum} + 1 != #{minimum} for #{supplier_num}" if last_minimum and minimum < last_minimum
        last_minimum = minimum

        marginal = @data.get(row, "PriceUSCol#{num}").to_f
        next if marginal == 0.0
        
        { :minimum => minimum,
          :fixed => Money.new(0),
          :marginal => Money.new(marginal)
        }
      end.compact

      raise "No Price" if prices.empty?

      costs = [
        { :fixed => Money.new(0),
          :minimum => prices.first[:minimum],
          :marginal => (prices.last[:marginal] * 0.6).round_cents
        },
        { :minimum => [prices.last[:minimum] * 2, 100].max }
      ]

      costs.unshift({
        :fixed => Money.new(36.00),
        :minimum => ((prices.first[:minimum] + 0.5) / 2).to_i,
        :marginal => (prices.last[:marginal] * 0.6).round_cents
      }) if prices.first[:minimum] > 1

      color_string = @data.get(row, 'ColorList')
      color_count = Integer(@data.get(row, 'ColorCount'))
      colors = color_string ? color_string.split(/\s*(?:,|(?:or))\s*/).sort : [nil]
      unless colors.length == color_count
        puts "Wrong number of colors: #{product['supplier_num']} #{colors.inspect} #{color_count}"
      end

      # Images
      path = "http://www.bulletline.com//images/#{product['supplier_num']}-large.jpg"
      product['image-thumb'] = product['image-main'] = TransformImageFetch.new(path)
      product['image-large'] = CopyImageFetch.new(path)

      # Decorations
      decorations = [{ 'technique' => 'None', 'location' => '' }]

      placement = @data.get(row, 'LogoPlacement')

      decoration_level = @data.get(row, 'CatalogRuncharges')
      decoration_level = decoration_level[-1..-1].to_i if decoration_level
      
      (1..6).each do |num|
        dec_string = @data.get(row, "Deco#{num}Location")
        next unless dec_string and !dec_string.blank?
        unless /^((?:Silkscreened)|(?:Laser Engraved)|(?:Debossed)|(?:Heat Transferred)),?\s*(.*?)\s*\:\s*(.+?)(?:\((.+)\))?$/i === dec_string
          puts "Unkown Dec: #{dec_string.inspect}"
          next
        end

        technique_str, location, area_str, misc = $1, $2, $3, $4
        technique, limit = @@decoration_replace[technique_str.downcase]
        raise "Unknown Technique: #{technique_str} : #{dec_string.inspect}" unless technique
        unless area = parse_area2(area_str)
          puts "Unkown Area: #{product['supplier_num']}: #{dec_string.inspect}"
          next
        end
        location ||= placement

        technique = technique + " - Level #{decoration_level}" if decoration_level and technique == 'Screen Print'

        decorations << {
          'technique' => technique,
          'limit' => limit,
          'location' => location
        }.merge(area)
      end
                       
      product['decorations'] = decorations

      dimension = @data.get(row, 'CatalogSize')

      unknown_variant_count = 1
      product['variants'] = colors.collect do |color|
        unless postfix = @@color_map[color]
          /^(?:(?:Solid )|(?:Metallic ))?(.+?)(?: with ([\w ]+?)(?:(?: Trim)|(?: Strap)|(?: Grip)|(?: Lower Barrel)|(?: Highlighter)|(?: Liner))?)?$/ === color
          postfix = [$1, $2].compact.collect do |sub|
            match = @@color_map[sub]
            unless match
              puts "Missing color #{product['supplier_num']}: #{color} - #{sub}" 
              match = "-#{unknown_variant_count}"
              unknown_variant_count += 1
            end
            match
          end.join
        end

#        puts "Postfix #{product['supplier_num']}: #{color} => #{postfix}" 

        { 'supplier_num' => "#{product['supplier_num']}#{postfix}",
          'color' => color,
          'material' => material,
          'dimension' => dimension,
          'prices' => prices,
          'costs' => costs,
        }
      end

      add_product(product)
    end
  end
end
