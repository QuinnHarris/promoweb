# -*- coding: utf-8 -*-
require 'csv'

class HitPromoCSV < GenericImport  

  def initialize(year)
    puts "Starting Fetch for #{year}"
    @src_file = WebFetch.new("http://www.hitpromo.net/fs/documents/hit_product_data_#{year}.csv").get_path(Time.now - 1.day)
    super 'Hit Promotional Products'
  end

#%w(colors_available imprint_colors approximate_size imprint_area set_up_charge multi_color_imprint packaging multi_panel_imprint second_side_imprint fob_zip second_handle_imprint please_note embroidery_information thread_colors tape_charge sizes approximate_bag_size optional_imprint second_positon non_woven_items label_color four_color_process optional_imprint_area second_position_imprint highlighters imprint catalog_page colors)
 
  def parse_products
    common_list = %w(product_name new description category product_photo colors_available imprint_colors approximate_size imprint_area set_up_charge multi_color_imprint packaging multi_panel_imprint second_side_imprint fob_zip second_handle_imprint please_note embroidery_information thread_colors tape_charge sizes approximate_bag_size optional_imprint precious_metal_imprint for_gold_banding for_halo battery second_positon non_woven_items label_color four_color_process optional_imprint_area second_position_imprint highlighters refills optional_carabiner imprint catalog_page optional_pen colors)

    price_list = %w(discount_code) + (1..8).collect { |n| ["price#{n}", "quantity#{n}"] }.flatten

    product_list = {}
    CSV.foreach(@src_file, :headers => :first_row, :col_sep => ' ', :quote_char => "'") do |row|
      unless /^(.+?)([BELST])?$/ === row['product_sku']
        raise "Bad Reg"
      end
      supplier_num = $1
      postfix = $2

      if hash = product_list[supplier_num]
        common_list.each do |name|
          raise "Mismatch: #{supplier_num} #{name} #{hash[name]} != #{row[name]}" unless hash[name] == ((row[name] == '--') ? nil : row[name])
        end
        price_hash = hash['price']
        puts "Duplicate Price: #{supplier_num} #{price_hash.inspect}" if price_hash[postfix]
      else
        hash = product_list[supplier_num] = common_list.each_with_object({}) do |name, hash|
          hash[name] = row[name] unless row[name] == '--'
        end
        price_hash = {}
      end

      price_hash[postfix] = price_list.each_with_object({}) do |name, hash|
        hash[name] = row[name]
      end
      hash['price'] = price_hash
    end

    puts "Len: #{product_list.length}"

    price_preference = %w(L S T E B)

    product_list.each do |supplier_num, hash|
      product_data = { 
        'supplier_num' => supplier_num,
        'name' => hash['product_name'],
        'supplier_categories' => [[hash['category'].strip]],
        'tags' => [] }

      product_data['description'] = hash['description'] ? hash['description'].split(/\s*\|\s*/).join("\n") : ''

      product_data['description'] += hash['please_note'].gsub(/\s*((<.+?>)|[^[[:ascii:]]])\s*/,' ').split(/\s*\n\s*/).join("\n") if hash['please_note']

      %w(precious_metal_imprint for_gold_banding for_halo refills optional_carabiner optional_pen battery).each do |name|
        next unless hash[name]
        str = "\n" + name.split('_').collect { |w| w.capitalize }.join(' ') + ": "
        str << hash[name].gsub(/<a href=".+?">(\d+)<\/a>/) do |str|
          product = get_product($1)
          "<a href='#{product.web_id}'>#{product.name}</a>"
        end
        product_data['description'] += str
      end

      product_data['tags'] << 'New' if hash['new']

      # Packaging
#      unless /(\d+) per carton.+?(\d+) lbs/ === hash['packaging']
#        raise "Unknown Packaging: #{hash['packaging'].inspect}"
#      end
#      product_data.merge!('package_units' => Integer($1),
#                          'package_weight' => Integer($2))


      # Prices
      price_string = hash['price'][hash['price'].keys.sort_by { |s| price_preference.index(s) }.first]
      prices = []
      costs = []
      discounts = convert_pricecodes(price_string['discount_code'])
      (1..8).each do |i|
        qty = price_string["quantity#{i}"]
        break if qty.blank?
        unless discounts.first
          puts "Extra Column: #{supplier_num}"
          break
        end
        
        base = {
          :fixed => Money.new(0),
          :minimum => Integer(qty) }

        price = Money.new(Float(price_string["price#{i}"]))
        prices << base.merge(:marginal => price)
        costs << base.merge(:marginal => price * (1.0 - discounts.shift))
      end
      raise "Discount doesn't match: #{supplier_num} #{discounts.inspect}" unless discounts.empty?
      costs << { :minimum => prices.last[:minimum] * 2 }
      common_variant = { 'prices' => prices, 'costs' => costs }

      common_properties = {}

      dimension = hash['approximate_size'] || hash['approximate_bag_size']
      common_properties.merge!( 'dimension' => parse_volume(dimension) ) if dimension


      product_data['images'] = [ImageNodeFetch.new(hash['product_photo'],
                                                   "http://www.hitpromo.net/imageManager/show/#{hash['product_photo']}")]

      decorations = [{
          'technique' => 'None',
          'location' => ''
        }]
      product_data['decorations'] = decorations

      colors = hash['colors_available']
        .scan(/(?:\s*([^,:]+?)(:|(?:\s*with)))?\s*(.+?)(?:\s*(?:(?:all)|(?:both))\s*with\s*(.+?))?(?:\.|$)/)
        .collect do |left, split, list, right|\

        list = list.split(/,|(?:\s+or\s+)/)
        split = split.include?(':') ? ' ' : " #{split.strip} " if split
        right = " with #{right}" if right
        list.collect { |e| (right && e.include?('with')) ? e : "#{left}#{split}#{e.strip}#{right}".strip }
      end.flatten.uniq

#      colors = hash['colors'].split(/\s*\|\s*/).compact.collect { |c| c.split(' ').collect { |w| w.capitalize }.join(' ') }

      product_data['variants'] = colors.collect do |color|
        { 'supplier_num' => "#{supplier_num}-#{color.gsub(' ', '')}"[0..63],
          'properties' => common_properties.merge('color' => color),
        }.merge(common_variant)
      end


      add_product(product_data)
    end
  end

end
