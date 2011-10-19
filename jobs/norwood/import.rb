require 'rexml/document'

class NorwoodAll
  def initialize
    @year = Date.today.year
    @colors = %w(Black White 186 202 208 205 211 1345 172 Process\ Yellow 116 327 316 355 341 Process\ Blue 293 Reflex\ Blue 281 2587 1545 424 872 876 877)
    @list =
[['AUTO', 'Barlow'],
 ['AWARD', 'Jaffa'],
 ['BAG', 'AirTex'],
 ['CALENDAR', 'TRIUMPH', %w(Reflex\ Blue Process\ Blue 032 185 193 431 208 281 354 349 145 469 109 Process\ Yellow 165)],
 ['DRINK', 'RCC'],
 ['GOLF', 'TeeOff'],
 ['GV', 'GOODVALU'],
 ['HEALTH', 'Pillow'],
 ['OFFICE', 'EOL'],
 ['WRITE', 'Souvenir', @colors + %w(569 7468 7433)],
 ['FUN', 'Fun'],
 ['HOUSEWARES', 'Housewares'],
 ['MEETING', 'Meeting'],
 ['TECHNOLOGY', 'Technology'],
 ['OUTDOOR', 'Outdoor'],
 ['TRAVEL', 'Travel'],
]
  end

  attr_reader :year, :colors, :list

  def fetch
    @list.each do |file, name|
      wf = WebFetch.new("http://norwood.com/files/productdata/#{year}/#{year} CSV #{file}.zip")
      path = wf.get_path(Time.now - 30.days)
      dst_path = File.join(JOBS_DATA_ROOT,'norwood')
      dst_file = File.join(dst_path,"#{year} CSV #{file}.csv")
      unless File.exists?(dst_file)
        #    File.unlink(dst_file)
        puts "unzip #{path} -d #{dst_path}"
        system("unzip #{path} -d #{dst_path}")
      end
    end
  end

  def apply_all(klass = NorwoodCSV)
    list.each do |file, name, c|
      import = klass.new("norwood/#{year} CSV #{file}.csv", name)
      import.set_standard_colors(c || @colors)
      import.run_parse_cache
      import.run_transform
      import.run_apply_cache
    end
  end

  def import_list
    return @import_list if @import_list
    @import_list = list.collect do |file, name, c|
      NorwoodCSV.new("norwood/#{year} CSV #{file}.csv", name)
    end
  end

  %w(parse_cache transform apply_cache).each do |name|
    define_method "run_#{name}" do
      import_list.each { |i| i.send("run_#{name}") }
    end
  end
end

#"Brand","Brand Name","Price Includes","Keywords","Country of Origin","Features","Small Image","Medium Image","Large Image","Zoom Image","Small Image URL","Medium Image URL","Large Image URL","Zoom Image URL",""Page Number","Price Message","Price Start Date","Quantity","Price","Net Price","Late Pricing Start Date","Late Quantities","Late Prices","Late Net Prices","EQP Net Minus 3%","EQP Net Minus 5%","Customer Price","Unit of Measure","Sizes","Size Name","Size Width","Size Length","Size Height","Rush Lead Time","Additional Lead Time to Canada","Canadian Lead Time","Selections","Proofs","Item Color Charges","Option Charges","Additional Product Information","FOB Ship From City","FOB Ship From State","FOB Ship From Zip","FOB Bill From City","FOB Bill From State","FOB Bill From Zip"

require 'csv'
class NorwoodCSV < GenericImport
  @@technique_replace = {
    'Offset' => '?'
  }

  def initialize(file_name, sub_supplier)
    @file_name = file_name
    super ["Norwood", sub_supplier]
  end

  attr_reader :doc
  
  @@sufixes = {
    %w(CALENDAR APPT) => 'Calendar',
    %w(GV GV_APPT) => 'Calendar',
    %w(CALENDAR COMM) => 'Calendar',
    %w(CALENDAR CUSTOM) => 'Calendar',
    %w(CALENDAR EXEC) => 'Calendar',
    %w(GV GV_BUSINESS) => 'Calendar',
    %w(CALENDAR NODATE) => 'Calendar',
    %w(CALENDAR NUDE) => 'Calendar',
    %w(CALENDAR POCKET) => 'Calendar',
    %w(GV GV_MINI) => 'Calendar',
    %w(CALENDAR SUC) => 'Calendar',

  }

  def parse_products
    puts "Reading: #{@file_name}"

    CSV.foreach(File.join(JOBS_DATA_ROOT,@file_name), :headers => :first_row) do |row|
      product_data = {
        'supplier_num' => supplier_num = row['Product ID'],
        'name' => row['Product Name'],
        'description' => row['Product Description'],
        'supplier_categories' => [%w(Category Sub-Taxonomy).collect { |n| row[n] }]
        }

      # Calendar Kludge
      if sufix = @@sufixes[product_data['supplier_categories'].first]
        unless product_data['name'].downcase.include?(sufix.downcase)
          product_data['name'] << " #{sufix}"
          puts "Append: #{product_data['supplier_num']}: #{product_data['name']}"
        end
      end

      if row['Country of Origin'] == 'United States'
        product_data['tags'] = %w(MadeInUSA)
      end

      # PAckage
      product_data['package_units'] = Integer(row['Pack Size'])
      unless row['Pack Weight'].blank?
        raise "Unkown weight: #{row['Pack Weight']}" unless /^(\d+(?:\.\d)?) ?(?:((?:lbs?)|(?:oz))\.?)?$/ === row['Pack Weight']
        product_data['package_weight'] = Float($1) * (($2 == 'oz') ? (1.0/16.0) : 1.0)
      end
        
      # Images
      zoom_img_url = "http://norwood.com/images/products/zoom/#{supplier_num}_Z.jpg"
      product_data['image-large'] = CopyImageFetch.new(zoom_img_url)
      product_data['image-main'] = TransformImageFetch.new(zoom_img_url)
      product_data['image-thumb'] = CopyImageFetch.new("http://norwood.com/images/products/medium/#{supplier_num}_M.jpg")
      
      properties = {}
      if size1 = row['Sizes']
        properties['dimension'] = parse_volume(size1)
      end
      
      unless (leadtime = row['Lead Time']).blank?
        product_data['lead_time_normal_min'] = product_data['lead_time_normal_max'] = Integer(leadtime)
      end
      unless (leadtime = row['Rush Lead Time']).blank?
        product_data['lead_time_rush'] = Integer(leadtime)
      end


      # Imprint
      decorations = [{
          'technique' => 'None',
          'location' => ''
        }]
      (1..6).each do |num|
        break if (technique = row["Imprint Method#{num}"]).blank?
        technique = @@technique_replace[technique] if @@technique_replace.has_key?(technique)
        
        location_str = row["Imprint Location#{num}"]
        raise "Unknown location: #{location_str}" unless /^(.+?):\s*(.+?)(?:,\s*(.+?))?\s*$/ === location_str
        location, area, limit = $1, $2, $3
        
        area = parse_area(area) if area
        colors = row["Imprint Colors#{num}"]  # UNUSED!!!
        
        decorations << {
          'technique' => technique,
          'location' => location,
          'limit' => limit && limit.to_i
        }.merge(area || {})
      end
      product_data['decorations'] = decorations
      
      
      # Price/Cost
      pre = ''
      if !(late_date = row['Late Pricing Start Date']).blank? and
          (Date.today > Date.parse(late_date))
        pre = 'Late '
      end
      prices = []
      costs = []
      (1..10).each do |num|
        break if row["#{pre}Price#{num}"].blank?
        price = Money.new(Float(row["#{pre}Price#{num}"]))
        discount = convert_pricecode(row["#{pre}Code#{num}"])
        quantity = Integer(row["#{pre}Quantity#{num}"])
        
        prices << { :marginal => price,
          :fixed => Money.new(0),
          :minimum => quantity }
        costs << prices.last.merge(:marginal => price * (1.0 - discount))
      end

      # Less than minimum
      unless costs.empty?
        costs.push({ :minimum => [(costs.last[:minimum] * (costs.length == 1 ? 4 : 2)), 100].max })
        
        ltm_price = 40.0
        if /Less Than Minimum \$(\d{2,3}\.\d{2})/ === row['Optional Charges']
          ltm_price = Float($1)*0.8
        end
        costs.unshift({ :fixed => Money.new(ltm_price),
                        :marginal => costs.first[:marginal],
                        :minimum => costs.first[:minimum] / 2
                      }) unless costs.first[:minimum] <= 1
      end

      common_properties = {}
      common_properties['material'] = row['Material'] unless row['Material'].blank?

      variants = [{}]
      count = 1
      (1..4).each do |num|
        name = row["Item Type#{num}"]
        next if name.empty?
        if name == 'Product Colors'
          name = 'color'
        else
          name = name.singularize
        end
        values = row["Item Colors#{num}"].split('|')
        count *= values.length
        break if count > 50
        
        variants = variants.collect do |prop|
          values.collect { |v| prop.merge(name => v) }
        end.flatten
      end

      product_data['variants'] = variants.collect do |properties|
        num_w = (32 - supplier_num.length-properties.length) / [properties.length,1].max
        num_suf = properties.keys.sort.collect { |k| '-' + properties[k].reverse[0...num_w].reverse.strip }.join
        { 'supplier_num' => supplier_num + num_suf,
          'prices' => prices,
          'costs' => costs,
          'properties' => properties.merge(common_properties)
        }
      end
      
      add_product(product_data)
    end
  end
end


# OLD XML VERSION
class NorwoodXML < GenericImport
  include REXML

  @@technique_replace = {
    'Offset' => '?'
  }

  def initialize(file_name, sub_supplier)
    @file_name = file_name
    super ["Norwood", sub_supplier]
  end

  attr_reader :doc
  
  @@sufixes = {
    %w(CALENDAR APPT) => 'Calendar',
    %w(GV GV_APPT) => 'Calendar',
    %w(CALENDAR COMM) => 'Calendar',
    %w(CALENDAR CUSTOM) => 'Calendar',
    %w(CALENDAR EXEC) => 'Calendar',
    %w(GV GV_BUSINESS) => 'Calendar',
    %w(CALENDAR NODATE) => 'Calendar',
    %w(CALENDAR NUDE) => 'Calendar',
    %w(CALENDAR POCKET) => 'Calendar',
    %w(GV GV_MINI) => 'Calendar',
    %w(CALENDAR SUC) => 'Calendar',

  }

  def parse_products
    puts "Reading: #{@file_name}"  
    doc = File.open(File.join(JOBS_DATA_ROOT,@file_name)) do |file|
      Document.new(file)
    end

    doc.root.get_elements('/root/Catalog/Category').each do |category|
      category_name = category.get_elements('CategoryName').first.text
      category_description = category.get_elements('CategoryDescription').first.text

      category.get_elements('Products/Product').each do |product|
        product_data = {
          'supplier_num' => supplier_num = product.get_elements('ProductID').first.text,
          'name' => product.get_elements('ProductName').first.text,
          'description' => (product.get_elements('ProductDescription').first.text || '').gsub(/\.\s+/,".\n"),
          'supplier_categories' => [%w(Taxonomy SubTaxonomy).collect { |n| product.get_elements(n).first.text }]
        }
        
#        puts "Num: #{product_data['supplier_num']}"

        # Calendar Kludge
        if sufix = @@sufixes[product_data['supplier_categories'].first]
          unless product_data['name'].downcase.include?(sufix.downcase)
            product_data['name'] << " #{sufix}"
            puts "Append: #{product_data['supplier_num']}: #{product_data['name']}"
          end
        end

        # Brand
        # BrandName

        if product.get_elements('Origin').first.text == 'United States'
          product_data['tags'] = %w(MadeInUSA)
        end

        # Images
        zoom_img_url = "http://norwood.com/images/products/zoom/#{supplier_num}_Z.jpg"
        product_data['image-large'] = CopyImageFetch.new(zoom_img_url)
        product_data['image-main'] = TransformImageFetch.new(zoom_img_url)
        product_data['image-thumb'] = CopyImageFetch.new("http://norwood.com/images/products/medium/#{supplier_num}_M.jpg")
        
        properties = {}
        if size1 = product.get_elements('MoreInfo/SIZES/Size/SizeConcat').first
          properties['dimension'] = parse_volume(size1.text)
        end

        if leadtime = product.get_elements('MoreInfo/LeadTime').first and leadtime.text != '{LEADTIME}' # Kludge for one product
          product_data['lead_time_normal_min'] = product_data['lead_time_normal_max'] = Integer(leadtime.text)
        end

        # Imprint
        decorations = [{
          'technique' => 'None',
          'location' => ''
        }]
        product.get_elements('ImprintMethods/ImprintMethod').each do |method|
          technique = method.get_elements('ImprintMethodName').first.text
          technique = @@technique_replace[technique] if @@technique_replace.has_key?(technique)

          area = method.get_elements('ImprintAreaDetail/ImprintDimension').first.text
          area = parse_area(area) if area
          included = Integer(method.get_elements('ImprintAreaDetail/ImprintIncludedColors').first.text)
          colors = method.get_elements('ImprintColors/ImprintColor').collect { |c| c.text }
                             
          decorations << {
            'technique' => technique,
            'location' => method.get_elements('ImprintAreaDetail/ImprintArea').first.text,
            'limit' => Integer(method.get_elements('ImprintAreaDetail/ImprintColorsMax').first.text)
          }.merge(area || {})
        end
        product_data['decorations'] = decorations

        # Pricing
        prices = []
        product.get_elements('PricingBreakQuantities/*').each do |elem|
          case elem.name
            when 'StartDate'
            if Date.parse(elem.text) < Date.today
              prices = []
            else
              break
            end
            
            when 'Quantity'
            prices << {} if prices.empty? || prices.last.has_key?(:minimum)
            prices.last[:minimum] = Integer(elem.text)
            
            when 'Price'
            prices << {} if prices.empty? || prices.last.has_key?(:marginal)
            prices.last[:marginal] = Money.new(Float(elem.text)).round_cents

            when 'Code'
            prices << {} if prices.empty? || prices.last.has_key?(:code)
            prices.last[:code] = elem.text

            when 'Pack'
            count = Integer(elem.text)
            if count > 1
              properties['Pack Of'] = count.to_s
            end
            product_data['package_units'] = count

            when 'Weight'
            unless elem.text.strip.empty?
              raise "Unkown weight: #{elem.text.inspect}" unless /^(\d+(?:\.\d)?) ?(?:((?:lbs?)|(?:oz))\.?)?$/ === elem.text
              mult = ($2 == 'oz') ? (1.0/16.0) : 1.0
              product_data['package_weight'] = Float($1) * mult
            end

            when 'UnitOfMeasure'

            when 'PriceMessage'

            when 'LegacyCode'
            
          else
            raise "Unknown Element: #{elem.name}"
          end
        end
        
        costs = []
        prices.each do |price|
          raise "Missing element: #{price.inspect}" unless price[:minimum] and price[:marginal] and price[:code]
          costs << {
            :fixed => Money.new(0),
            :marginal => (price[:marginal] * (1.0 - convert_pricecode(price.delete(:code)))).round_cents,
            :minimum => price[:minimum]
          }
        end

        unless costs.empty?
          costs.push({ :minimum => [(costs.last[:minimum] * (costs.length == 1 ? 4 : 2)), 100].max })

          # Less than Minimum (different for calendars!!!)
          ltm_price = 40.0
          if ltm_node = product.get_elements("OptionCharges/OptionalCharge[@descr='Less Than Minimum']").first
            ltm_price = Float(ltm_node.attributes['price']) * (1 + Float(ltm_node.attributes['adj_percent'])/100.0)
          end
          costs.unshift({ :fixed => Money.new(ltm_price),
                          :marginal => costs.first[:marginal],
                          :minimum => costs.first[:minimum] / 2
                        }) unless costs.first[:minimum] <= 1
        end

        colors = product.get_elements('*/ItemColors/ItemColor').collect { |i| i.text && i.text.strip }.compact.uniq
        colors = [nil] if colors.empty?

        product_data['variants'] = colors.collect do |color|
          { 'supplier_num' => "#{supplier_num}#{color && '-' + color}"[0...32],
            'prices' => prices,
            'costs' => costs,
            'color' => color,
            'properties' => properties
          }
        end

        add_product(product_data)
      end
    end
    
  end
end
