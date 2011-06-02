# -*- coding: utf-8 -*-
require 'rexml/document'

class HighCaliberLine < GenericImport
  def initialize(name, domain)
    @src_file = File.join(JOBS_DATA_ROOT,"#{name}.xml")
    @domain = domain
    super name
  end

  def imprint_colors
    %w(186 021 Process\ Yellow 123 161 347 342 281 Process\ Blue Reflex\ Blue 320 266 225 195 428 430 White Black 877 872)
  end
  
  def parse_products
    puts "Reading XML"
    doc = File.open(@src_file) { |f| REXML::Document.new(f) }
    
    puts "Parsing"
    doc.root.each_element do |row|
      product_data = {}
      
      {
        'supplier_num' => 'pid',
        'name' => 'pname',
      }.each do |our, their|
        product_data[our] = row.get_elements(their).first.get_text.to_s.strip
      end
      
      product_data['supplier_num'] = product_data['supplier_num'].split(' ').first

      next if %w(S-606 T-818 K-175).include?(product_data['supplier_num'])
      
      next if product_data['name'].empty?

      product_data['name'].gsub!(/\s+/, ' ')
      
      product_data['description'] = %w(desp desp1).collect do |n|
        next nil unless e = row.get_elements(n).first 
        (e.text || '').gsub(/<.*?>/,' ')
      end.compact.join("\n").gsub(/\s+/,' ').gsub(/\s?\.\s/,"\n").gsub(/\s?•\s/,"\n").strip
      
      
      puts "Product: #{product_data['supplier_num']}"
      
      # Categories
      categories = %w(cname sname fname).collect do |catname|
        next nil unless e = row.get_elements(catname).first
        str = e.get_text.to_s.strip.gsub('&amp;','&').gsub(/\s+/, ' ')
        str.empty? ? nil : str
      end.compact
      
      product_data['tags'] = []
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

      image_str = row.get_elements('image').first.get_text.to_s.strip.downcase
      { 'new' => 'New',
        'usa' => 'MadeInUSA',
        'bio green' => 'Eco',
        'price buster' => 'Special' }.each do |str, tag|
        product_data['tags'] << tag if image_str.include?(str)
      end

      product_data['tags'].uniq!
      
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

      imprint_str = row.get_elements('imprint').first.get_text.to_s.strip
      imprint_area = parse_area2(imprint_str.gsub('”', '"').gsub('&quot;', '"'))
      puts "Imprint: #{imprint_str.inspect} => #{imprint_area.inspect}" unless imprint_area
      if imprint_area
        decorations << { 'technique' => 'None', 'location' => '' }
        decorations << {
          'technique' => 'Screen Print',
          'limit' => 4,
          'location' => ''
        }.merge(imprint_area)
      end
        
      product_data['decorations'] = decorations
      
      # Package Info
      unless (weight_str = row.get_elements('weight').first.get_text.to_s.strip).empty?
        unless /(\d+)\s*[lI]bs\s*\/\s*(\d+(,\d{3})?)\s*pcs\s*(?:-?\s*(.+?))?\s*(?:\(.+?\)?)?\s*(.+?)?/i =~ weight_str
          puts  " !!! Unknown Weight: #{weight_str.inspect}"
        end
        #        puts " Weight: #{weight_str} => #{$1} lbs / #{$2} pcs  :  #{$3.inspect}"
        product_data.merge!({
      'package_weight' => $1.to_f,
      'package_units' => $2 && $2.gsub(',','').to_i
        })
      end
      
      # Price Info (common to all variants) 
      price_list = []
      cost_list = []
      

      lead_times = []

      # factory
      %w(stock).each do |price_type|
        range = row.get_elements("#{price_type[0..0]}range").first.get_text.to_s.strip
        if range.empty?
          puts "No Range"
          next
        end
        raise "Unknown Range: #{range.inspect}" unless /^([\d,-]+).*?(?:\((.+?)\))?$/ =~ range
        codes = convert_pricecodes($2 || "5R")
        brks = $1.scan(/[\d,]+/).collect { |s| s.gsub(',','').to_i }
        #        puts " Qty: #{price_type}: #{range.inspect} => #{brks.inspect} : #{codes.inspect}"
        
#        times = []
        price_breaks = brks.collect { |b| { :minimum => b } }
        
        elem = row.get_elements("#{price_type}prize").first
        elem = row.get_elements("price").first unless elem
        elem.get_text.to_s.split(/[\n\r]/).each do |line|
          # line = (type)  (price|N/A) (price)... (price|Free)...
          unless /^(.+?)((?:(?:\$?\d+\.\d{2})|(?:Free)|(?:\$?N\/A)).+)$/i =~ line
            puts " !!! Unknown Price: #{line.inspect}"
            next
          end
          type = $1.strip
          # Put a # because of F up
          list = $2.scan(/(?:(?:\$|#)?\s*(\d+\.\d{2}))|(?:Free[^\*])|((?:\$?N\/A)|(?:QUR))/).collect { |n, o| n.to_f unless o }
          #puts " List: #{type} : #{$2.inspect} => #{list.inspect}"
          
          if price_breaks.length > list.length
            puts " !!! Mismatch index #{price_breaks.inspect} <=> #{list.inspect}"
            list << list.last
          end
          
#          puts "T: #{type.inspect}  L: #{list.inspect}"

          if /(Set[ -]+?Up)|(Digitizing)/ =~ type
            price_breaks.zip(list) { |h, n| h[:fixed] = Money.new(0) }
            next nil
          else
#            times << type
            overwrites = 0
            price_breaks.zip(list).each_with_index do |(h, n), i|
              unless h[:marginal] and n and h[:marginal].to_f <= n
                puts "Mismatch skip #{i}" if overwrites == 0 and i != 0
                overwrites += 1
                h[:marginal] = Money.new(n) if n
              end
              puts "Mismatch overwrite: #{overwrites} #{i}: #{price_breaks.inspect} : #{list.inspect}" unless overwrites == 0 or overwrites == (i + 1)
            end
          end

          case type
          when /^(\d{1,2})-(\d{1,2}) Day/
            lead_times << [Integer($1), Integer($2)]
          when /^(\d+) Day/i
            days = Integer($1)
            lead_times << [days, days]
          when /^24\s*H(ou)?r/i, /23\s*hr/i
            lead_times << [1, 1]
          when /^48\s*H(ou)?r/i
            lead_times << [2, 2]
          when /^(\d{1,2})-(\d{1,2}) Week/
            lead_times << [Integer($1)*5, Integer($2)*5]
          when /^(\d{1,2}) Week/
            days = Integer($1)*5
            lead_times << [days, days]
          else
            puts "Unknown: #{type}"
          end
        end

        lead_times.uniq!
        raise "Too many leeds: #{lead_times.inspect}" if lead_times.length > 3
        lead_times.sort!
        la = lb = 0
        lead_times.each do |ca, cb| 
          raise "non sequential" if la > ca || lb > cb
          la, lb = ca, cb
        end
        if lead_times.length > 1
          product_data['lead_time_rush'] = lead_times.first.last
          product_data['lead_time_rush_charge'] = 1.0
        end

        # Set Lead Times
        unless lead_times.empty?
          if lead_times.length == 1 && lead_times.first.first <= 2
            product_data['lead_time_rush'] = lead_times.first.first
            product_data['lead_time_normal_min'] = 5
            product_data['lead_time_normal_max'] = 7
          else
            product_data['lead_time_normal_min'] = lead_times.last.first
            product_data['lead_time_normal_max'] = lead_times.last.last
          end
        end

        price_breaks.delete_if { |b| b[:marginal].nil? }
        #        price_breaks.delete_if { |b| b[:minimum] <= price_list.last[:minimum] or b[:marginal] >= price_list.last[:marginal] } if price_list.last
        
        #next unless cost_column = price_breaks.last # price_breaks.zip(codes).reverse.find { |b, m| b[:marginal] and !b[:marginal].nil?  and m }
        if price_breaks.empty?
          puts "Empty Price Breaks"
          next
        end

        # Less Than Minimum
        price_list << {
          :minimum => price_breaks.first[:minimum] / 2,
          :fixed => Money.new(25.00),
          :marginal => price_breaks.first[:marginal]
        }
        
        cost_list << {
          :minimum => price_breaks.first[:minimum] / 2,
          :fixed => Money.new(25.00),
          :marginal => (price_breaks.first[:marginal] * (1.0 - codes.last)).round_cents
        }
        
        # Other Price
        price_list += price_breaks
        
        cost_list << {
          :minimum => price_breaks.first[:minimum],
          :fixed => Money.new(0),
          :marginal => (price_breaks.last[:marginal] * (1.0 - codes.last)).round_cents
        }
      end
      
      if price_list.empty?
        puts "Empty Price List"
        next 
      end
      
      cost_list << {
        :minimum => (price_list.last[:minimum] * 1.5).to_i,
      } unless cost_list.empty?
      #      puts "Breaks: #{price_list.inspect}"
      
      size_str = row.get_elements('size').first.get_text.to_s.strip
      size_clean = size_str.gsub(/\(.+?\)/,'').gsub('&quot;','"')
      dimension = size_clean.blank? ? nil : size_clean #parse_volume(size_clean)
      #      puts " Size: #{size_str.inspect} => #{size_clean.inspect} => #{dimension.inspect}"
      
      
      color_str = row.get_elements('desp2').first.get_text.to_s.strip
      if /Standard Lanyard Material colors\.?(?:&lt;br&gt;)?(.*)/i === color_str
        product_data['description'] += "\n#{$1}" unless $1.blank?
        color_list = %w(black brown burgundy forest\ green gray green light\ blue navy\ blue orange purple red reflex\ blue teal white yellow).collect do |name|
          [name.capitalize, LocalFetch.new(File.join(JOBS_DATA_ROOT, 'HighCaliber-Lanyard-Swatches'), "#{name}.jpg")]
        end
      elsif row.get_elements('desp1').first.get_text.to_s.strip.include?('19 Standard Neoprene')
        color_list = %w(Maroon Red Grey Orange Gold Yellow Teal Bright\ Pink Bright\ Green Pink Bright\ Orange Purple Green Deep\ Royal Royal Navy White Charcoal Black)
      else
        if color_str.include?('and') and color_str.include?('or')
          color_list = color_str.split(/\s*(?:(?:\s+or\s+)|,|\.|(?:Trims?\.?))\s*/)
        else
          color_list = color_str.split(/\s*(?:(?:\s+or\s+)|(?:\s+and\s+)|,|\.|(?:Trims?\.?))\s*/)
        end
        #      puts " Color: #{color_str.inspect} => #{color_list.inspect}"
      
        color_list << nil if color_list.empty? # Always need one variant
      end
      
      product_data['variants'] = color_list.uniq.collect do |color, swatch|
        { 'supplier_num' => (product_data['supplier_num'] + (color ? "-#{color}" : ''))[0...32],
      'dimension' => dimension,
      'prices' => price_list,
      'costs' => cost_list,
      'color' => color,
      'swatch-medium' => swatch
        }
      end
      
      add_product(product_data)
    end
  end
end
