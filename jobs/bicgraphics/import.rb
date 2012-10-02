require 'csv'

class BicGraphics < GenericImport
  def initialize(year)
    base = File.join(JOBS_DATA_ROOT, "#{year}_NWBG_DATA")
    @data_file = File.join(base, "#{year}_BIC_DATA.csv")
    @price_file = File.join(base, 'item_prices_USA.csv')
    super 'Bic Graphics'
  end
  
  def parse_prices(price_file)
    results = {}
    CSV.foreach(price_file) do |row|
      supplier_num = row[0]
      discounts = convert_pricecodes(row[15])

      prices = []
      costs = []

      (0..7).each do |i|
        break if row[1+i*2].blank?
        price = Money.new(Float(row[2+i*2]))
        base = { :fixed => Money.new(0),
          :minimum => Integer(row[1+i*2]) }
        prices << base.merge(:marginal => price)
        costs << base.merge(:marginal => price * (1.0-discounts.shift))
      end

      raise "Discount doesn't match: #{supplier_num}" unless discounts.empty?

      results[supplier_num] = { 'prices' => prices, 'costs' => costs }
    end
    results
  end

# Item #,Product Name,Additional Description,Thickness,SheetCount,Features,Product Color,Additional Product Color,Additional Product Color2,Imprint options,Imprint_Options_2,Location1,Location2  ,Location3,Location4,Point Style_1,Ink_Color_1,Point Style_2,Ink_Color_2,Ink_Options,Pricing Info,Production time,Imprint Info,Product Dimensions,US  Patent,Recycle  Info,Shipping  Info,Pack Qty,Pack Weight,Icons,Page Number

  cattr_reader :color_map
  @@color_map = {}
  
  def parse_products
    @categories = {}
    @image_list = get_ftp_images({ :server => 'library.norwood.com',
                                  :login => 'images', :password => 'norwood' },
                                 'BIC 2012 Product Images/2012_Hi_Res_Images', true) do |path, file|
      if /\/([A-Z0-9]+)(?:\/|$)/ === path
        product = $1
        if /^([A-Z0-9]+)(?:[_.-]?(.+?))?\.jpg$/ === file #&& $1 == product
          @categories[product] = path.split('/')[-2]
          [file, product, $2]
        end
      end
    end

    product_prices = parse_prices(@price_file)
    CSV.foreach(@data_file, :headers => :first_row, :encoding => 'windows-1251:utf-8') do |row|
      supplier_num = row['Item #'].strip

      base_num = supplier_num
      [/^MG[A-Z]{2,4}(\d{2})(?:-\d{1,2})?$/,
       /^MP[A-Z]{0,4}\d([A-Z])$/,
       /^(T)537R\d$/].each do |regexp|
        base_num = supplier_num.gsub($1, '') if regexp === supplier_num
      end

      product_data = {
        'supplier_num' => supplier_num,
        'name' => row['Product Name'].gsub('?', '&reg;'),
        'description' => %w(Features Additional\ Description Ink_Options Additional\ Product\ Color Additional\ Product\ Color2 Pricing\ Info Imprint\ Info Recycle\ \ Info Shipping\ \ Info).collect do |field|
          next nil if row[field].blank?
          next nil if /^#+$/ === row[field]
          row[field].gsub('?', '&reg;').split(/\s*(?:(?:\|\s*)|(?:\.\s+))/).collect { |s| s.blank? ? nil : s }
        end.flatten.compact.join("\n"),
        'supplier_categories' => [[@categories[base_num] || 'unkown']],
        'tags' => [],
        'package_units' => (row['Pack Qty'].to_i.to_s == row['Pack Qty']) && Integer(row['Pack Qty'])
      }

      if /^(\d+)\s+lbs/ === row['Pack Weight']
        product_data['package_weight'] = Float($1)
      end

      product_data['description'] += "\n" + row['US  Patent'].strip if row['US  Patent']
            
      if row['Icons']
        { 'ECO' => 'Eco',
          'USA' => 'MadeInUSA' }.each do |icon, tag|
          product_data['tags'] << tag if row['Icons'].include?(icon)
        end

        if row['Icons'].include?('24')
          product_data['lead_time_rush'] = 1
        end
      end
        
      # Doesnt work right on secondary numbers
      unless /(\d{1,2}) working.+(?:(\d) additional)?(?:(\d{1,2}) working)?/ === row['Production time']
        raise "Unkown Time: #{row['Production time'].inspect}"
      end

      product_data['lead_time_normal_min'] = normal_min = Integer($1)
      product_data['lead_time_normal_max'] = ($3 && Integer($3)) || ($2 && (normal_min + Integer($2))) || normal_min
      
      common_properties = {
        'dimension' => row['Product Dimensions'] && parse_volume(row['Product Dimensions']),
        'sheet count' => row['SheetCount'],
        'thickness' => row['Thickness']
      }

      variants = [{}]

      differ_prop = []

      colors = []
      if row['Product Color']
        colors = row['Product Color'].split(/(?:,\s*)+/).uniq
        unless (descrip = colors.find_all { |c| c.length > 32 }).empty?
          colors -= descrip
          product_data['description'] += descrip.collect { |d| "\n#{d}"}.join
        end
        differ_prop << 'color' if colors.length > 1
        variants = variants.collect do |v|
          colors.collect do |color|
            v.merge('color' => color.strip)
          end
        end.flatten unless colors.empty?
      end

      points = (1..2).collect do |i|
        next nil unless point_style = row["Point Style_#{i}"]
        point_colors = row["Ink_Color_#{i}"].split(/,\s*/)
        differ_prop << 'ink color' if point_colors.length > 1 and !differ_prop.include?('ink color')
        point_colors.collect do |color|
          { 'point style' => point_style, 'ink color' => color }
        end
      end.compact
      differ_prop << 'point style' if points.length > 1
      points = points.flatten
      
      variants = variants.collect do |v|
        points.collect do |hash|
          v.merge(hash)
        end
      end.flatten unless points.empty?

      product_data['supplier_categories'] += (1..2).collect do |i|
        case row["Point Style_#{i}"]
        when /Point/
          ['Writing Instruments', 'Ballpoint']
        when /Roller Ball/
          ['Writing Instruments', 'Rollerball']
        when /Gel Ink/
          ['Writing Instruments', 'Gel Pen']
        when /Pencil/
          ['Writing Instruments', 'Pencil']
        when /Highlighter/
          ['Writing Instruments', 'Highlighter']
        when /Marker/
          ['Writing Instruments', 'Marker']          
        when nil
        else
          puts "Unkown Point Style: #{row["Point Style_#{i}"]}"
          nil
        end
      end.compact

      
      decorations = [{
          'technique' => 'None',
          'location' => ''
        }]
      product_data['decorations'] = decorations

      color_image_map, color_num_map = match_colors(colors, {}, base_num)

      product_data['images'] = [ImageNodeFetch.new(file = "#{base_num}_phto_lrg.jpg",
                                                   "http://www.bicgraphic.com/images/large/#{file}")] +
        color_image_map[nil]

      product_data['variants'] = variants.collect do |properties|
#        puts "Prop: #{supplier_num} #{properties.inspect}"
        postfix = differ_prop.map { |p| "-#{properties[p]}" }.join
        { 'supplier_num' => (supplier_num + postfix)[0..63],
          'properties' => properties.merge(common_properties),
          'images' => properties['color'] && color_image_map[properties['color']]
        }.merge(product_prices[supplier_num] || {})
      end

      add_product(product_data)
    end
  end
  
end
