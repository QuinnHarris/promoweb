require 'csv'

class HitPromoCSV < GenericImport  

  def initialize(year)
    puts "Starting Fetch for #{year}"
    @src_file = WebFetch.new("http://www.hitpromo.net/fs/documents/hit_product_data_#{year}.csv").get_path(Time.now - 1.day)
    super 'Hit Promotional Products'
  end

 
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
          raise "Mismatch: #{supplier_num} #{name} #{hash[name]} != #{row[name]}" unless hash[name] == row[name]
        end
        price_hash = hash['price']
        puts "Duplicate Price: #{supplier_num} #{price_hash.inspect}" if price_hash[postfix]
      else
        hash = product_list[supplier_num] = common_list.each_with_object({}) do |name, hash|
          hash[name] = row[name]
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
        'supplier_categories' => [[hash['category']]],
        'tags' => [] }

      product_data['description'] = hash['description'].split(/\s*|\s*/).join("\n")

      product_data['tags'] << 'new' if hash['new']


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
      common_variant = { 'prices' => prices, 'costs' => costs }

      common_properties = {}


      product_data['images'] = [ImageNodeFetch.new(hash['product_photo'],
                                                   "http://www.hitpromo.net/imageManager/show/#{hash['product_photo']}")]

      decorations = [{
          'technique' => 'None',
          'location' => ''
        }]
      product_data['decorations'] = decorations

      colors = hash['colors_available'].split(/\s*,\s*/)

      product_data['variants'] = colors.collect do |color|
        { 'supplier_num' => "#{supplier_num}-#{color}",
          'properties' => common_properties.merge('color' => color),
        }.merge(common_variant)
      end


      add_product(product_data)
    end
  end

end
