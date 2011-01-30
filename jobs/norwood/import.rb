require 'rexml/document'

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
        
        puts "Num: #{product_data['supplier_num']}"

        # Calendar Kludge
        if sufix = @@sufixes[product_data['supplier_categories'].first]
          unless product_data['name'].downcase.include?(sufix.downcase)
            product_data['name'] << " #{sufix}"
            puts "Append: #{product_data['name']}"
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
