# -*- coding: utf-8 -*-
require 'rexml/document'

class HighCaliberLine < GenericImport
  def initialize
    @src_file = File.join(JOBS_DATA_ROOT,"High Caliber Line.xls")
    @domain = "www.highcaliberline.com"
    super "High Caliber Line"
  end

  def imprint_colors
    %w(186 021 Process\ Yellow 123 161 347 342 281 Process\ Blue Reflex\ Blue 320 266 225 195 428 430 White Black 877 872)
  end
  
  def parse_products
    puts "Reading XML"
    xls = XLSFile.new(@src_file)

    lanyard_color_list = %w(black brown burgundy forest\ green gray green light\ blue navy\ blue orange purple red reflex\ blue teal white yellow).collect do |name|
      [name.capitalize, name.capitalize, LocalFetch.new(File.join(JOBS_DATA_ROOT, 'HighCaliber-Lanyard-Swatches'), "#{name}.jpg")]
    end

    name_list = %w(Maroon Red Grey Orange Gold Yellow Teal Bright\ Pink Bright\ Green Pink Bright\ Orange Purple Green Deep\ Royal Royal Navy White Charcoal Black)
    pms_list = %w(209 200 429 165 123 YELLOW 3165 812 802 RHODAMINE RED 804 VIOLET 3308 286 293 289 WHITE 432 PROCESS\ BLACK)
    neoprene_color_list = name_list.zip(pms_list).collect { |n, p| [n, "#{n} (PMS #{p})"] }
    
    puts "Parsing"
    xls.worksheet.each(1) do |row|
      product_data = {}
      
      {
        'supplier_num' => 'Product ID',
        'name' => 'Product Name',
      }.each do |our, their|
        product_data[our] = xls.get(row, their).strip
      end
      
      next if %w(S-606 T-818 K-175).include?(product_data['supplier_num'])
      
      next if product_data['name'].empty?

      puts "Product: #{product_data['supplier_num']}"

      product_data['name'].gsub!(/\s+/, ' ')
      
      if description = xls.get(row, 'Description')
        product_data['description'] = description.gsub(/\s+/,' ').gsub(/\s?\.\s/,"\n").gsub(/\s?•\s/,"\n").strip
      end

      no_less_than_min = no_blank = nil
      product_data['tags'] = []
      case product_data['description']
      when /BioGreen/
        product_data['tags'] << 'Eco'
      when /USA/
        product_data['tags'] << 'MadeInUSA'
      when /neoprene/i
        no_less_than_min = no_blank = true
      end
        
      
      # Categories
      categories = %w(Category Sub-Categories).collect do |catname|
        str = xls.get(row, catname)
        str && str.strip.gsub('&amp;','&').gsub(/\s+/, ' ')
      end.compact
      
      categories.delete_if do |category|
        case category
          when /Price Buster/i
          product_data['tags'] << 'Special'
          when /Factory Direct/i
          true
          when /Fast Track/i
          true
          when /In Stock/i
          true
        end
      end
      
      if prod = @product_list.find { |p| p['supplier_num'] == product_data['supplier_num'] }
        prod['supplier_categories'] << categories
        prod['supplier_categories'].uniq!
        puts " Same product: Added #{categories.inspect}"
        next
      end
      
      #      puts "Categories: #{categories.inspect}"
      product_data['supplier_categories'] = [categories]
      
      # Image
      file_name = "#{product_data['supplier_num']}.jpg"
      product_data['image-large'] = product_data['image-main'] = CopyImageFetch.new(
    "http://#{@domain}/admin/productimage/high_res/#{file_name}")
      
      product_data['image-thumb'] = CopyImageFetch.new(
    "http://#{@domain}/admin/productimage/auto/#{file_name}")
      
      # Decorations
      decorations = []

      if imprint_str = xls.get(row, 'Imprint Size')
        imprint_str.split(/,|(?:\s{2,3})/).each do |imprint_part|
          unless /^(?:(.+?):)?\s*(.+?)(?:(.+?)\))?$/ === imprint_part
            puts "Imprintt: #{imprint_str.inspect}"
          end
          location, qualify = $1, $3
          imprint_area = $2 && parse_area2($2.strip.gsub('”', '"').gsub('&quot;', '"'))
          puts "Imprint: #{imprint_str.inspect} => #{imprint_area.inspect}" unless imprint_area
          if imprint_area
            decorations << { 'technique' => 'None', 'location' => '' } unless no_blank
            decorations << {
              'technique' => 'Screen Print',
              'limit' => 4,
              'location' => location || ''
            }.merge(imprint_area)
          end
        end
      end

      product_data['decorations'] = decorations
      
      # Package Info
      if weight_str = xls.get(row, 'Weight')
        unless /^\s*(\d+)\s*lbs\s*\/\s*(\d+)\s*pcs?/ === weight_str
#        unless /(\d+)\s*[lI]bs\s*\/\s*(\d+(,\d{3})?)\s*pcs\s*(?:-?\s*(.+?))?\s*(?:\(.+?\)?)?\s*(.+?)?/i =~ weight_str
          puts  " !!! Unknown Weight: #{weight_str.inspect}"
        end
        #        puts " Weight: #{weight_str} => #{$1} lbs / #{$2} pcs  :  #{$3.inspect}"
        product_data.merge!({
      'package_weight' => $1.to_f,
      'package_units' => $2 && $2.gsub(',','').to_i
        })
      end
      
      # Price Info (common to all variants)     
      price_list = (1..5).collect do |num|
        qty = xls.get(row, "Qty #{num}")
        next if qty.blank?
        { :minimum => Integer(qty.is_a?(String) ? qty.gsub(/[^0-9]/,'') : qty),
          :marginal => Money.new(Float(xls.get(row, "Price #{num}"))),
          :fixed => Money.new(0) }
      end.compact

      if price_list.empty?
        puts "Empty Price List"
        next 
      end

      cost_list = [{
          :minimum => price_list.first[:minimum],
          :fixed => Money.new(0),
          :marginal => (price_list.last[:marginal] * 0.6).round_cents
        },{
          :minimum => (price_list.last[:minimum] * 1.5).to_i,
        }]

      unless no_less_than_min
        cost_list.unshift({
          :minimum => price_list.first[:minimum] / 2,
          :fixed => Money.new(25.00),
          :marginal => (price_list.first[:marginal] * 0.6).round_cents
        })

        price_list.unshift({
          :minimum => price_list.first[:minimum] / 2,
          :fixed => Money.new(25.00),
          :marginal => price_list.first[:marginal]
        })          
      end


      # Leed Time
      begin
        case xls.get(row, 'Production Time')
        when /^(\d{1,2})-(\d{1,2}) Day/
          min, max = Integer($1), Integer($2)
        when /^(\d+) Day/i
          min = max = Integer($1)
        when /^24\s*H(ou)?r/i, /23\s*hr/i
          min = max = 1
        when /^48\s*H(ou)?r/i
          min = max = 2
        when /^(\d{1,2})-(\d{1,2}) Week/
          min, max = Integer($1)*5, Integer($2)*5
        when /^(\d{1,2}) Week/
          min = max = Integer($1)*5
        else
          min = max = nil
          puts "Unknown: #{type}"
        end
        product_data['lead_time_normal_min'] = min
        product_data['lead_time_normal_max'] = max
      end
      
      if dimension = xls.get(row, 'Size')
        dimension = dimension.gsub(/\(.+?\)/,'').gsub('&quot;','"')
      end     
      
      if color_str = xls.get(row, 'Colors')
        if /Standard Lanyard Material colors\.?(?:&lt;br&gt;)?(.*)/i === color_str
          product_data['description'] += "\n#{$1}" unless $1.blank?
          color_list = lanyard_color_list
        elsif product_data['description'].downcase.include?('neoprene')
          color_list = neoprene_color_list
        else
          if color_str.include?('and') and color_str.include?('or')
            color_list = color_str.split(/\s*(?:(?:\s+or\s+)|,|\.|(?:Trims?\.?))\s*/)
          else
            color_list = color_str.split(/\s*(?:(?:\s+or\s+)|(?:\s+and\s+)|,|\.|(?:Trims?\.?))\s*/)
          end
          color_list << nil if color_list.empty? # Always need one variant
        end
      else
        color_list = [nil]
      end
      
      product_data['variants'] = color_list.uniq.collect do |id, name, swatch|
        { 'supplier_num' => (product_data['supplier_num'] + (id ? "-#{id}" : ''))[0...32],
          'dimension' => dimension,
          'prices' => price_list,
          'costs' => cost_list,
          'color' => name || id,
          'swatch-medium' => swatch
        }
      end
      
      add_product(product_data)
    end

    # Remove California Line
    @product_list.delete_if { |p| p['supplier_categories'].include?('California Line') }
  end
end
