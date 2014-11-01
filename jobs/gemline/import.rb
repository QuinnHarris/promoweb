# -*- coding: utf-8 -*-

class GemlineXML < GenericImport
  @@decoration_replace = { 'Print' => ['Screen Print', 6],
  'Embroidery' => ['Embroidery', 20000],
  'Embroider' => ['Embroidery', 20000],
  'Deboss' => ['Deboss', 2],
  'Personalization' => ['Personalization', nil],
  'Patch' => ['Patch', nil],
  'LogoMagic' => ['LogoMagic', nil],
  'Gemphoto/Heat Transfers' => ['Photo Transfer', nil],
  'Gemphoto' => ['Photo Transfer', nil],
  'Print (one color only)' => ['Screen Print', 1],
  "Print (case only – one color print)" => ['Screen Print', 1],
  'Initials' => ['Personalization', nil],
  'Laser Engraving' => ['Laser Engrave', 1]}

  def fetch_parse?
    return nil unless super

    if File.exists?(@src_file) and
        File.mtime(@src_file) >= (Time.now - 1.day)
      puts "File Fetched today"
      return
    end
    
    puts "Starting Fetch"
    
    agent = Mechanize.new
    page = agent.get('http://www.gemline.com/gemline/distributor-tools/downloads.aspx')
   
    form = page.forms.first
    form.add_field!('__EVENTTARGET', 'ctl00$ContentPlaceHolder2$downloads_r$lnkProductDataXML')
    form.add_field!('__EVENTARGUMENT', '')
    page = agent.submit(form)
    
    name = /filename=\"(.*)\"/.match(page.response['content-disposition'])[1]
    path = File.join(JOBS_DATA_ROOT,name)
    
    page.save_as path
    
    FileUtils.ln_sf(name, @src_file)
    
    puts "Fetched"

    true
  end

  def initialize
    file_name = "Gemline.xml"
    @src_file = File.join(JOBS_DATA_ROOT,file_name)
    super "Gemline"
  end
  
  def parse_categories(element)
    return [] unless element
    categories = []
    element.elements.each do |category|
      first = category['name'].gsub('&amp;','&')
      category.elements.each do |sub|
        categories << [first, sub['name'].gsub('&amp;','&')]
      end
    end
    categories.uniq
  end
  
  def parse_products
    puts "Reading XML"  
    doc = File.open(@src_file) { |f| Nokogiri::XML(f) }
    
    doc.xpath('/xml/gemlineproductdata/product').each do |product|
      ProductDesc.apply(self) do |pd|       
        # Product Record
        pd.supplier_num = product['mainstyle']
        pd.name = product['name']
        pd.description = product['description'].split('^')
        pd.data = { :id => product['Id'] }  # ID used by the website to identify products, needed to provide link to website.
        pd.images = [] # Suppress warnings, all images in variants
        
        # From http://www.gemline.com/Gemline/services/index.aspx?id=140
        pd.lead_time.normal_min = 4
        pd.lead_time.normal_max = 7
        pd.lead_time.rush = 1
        
        pd.package.merge_from_object(product,
                                     { 'units'  => 'products_per_box',
                                       'weight' => 'box_weight',
                                       'height' => 'box_height_inches',
                                       'width'  => 'box_width_inches',
                                       'length' => 'box_length_inches' })
        
        dimension = %w(diameter length height width).each_with_object({}) do |n, hash|
          hash[n] = product[n].to_f if product[n] and product[n].to_f != 0.0
        end
        pd.properties['dimension'] = dimension unless dimension.empty?
        
        # Decorations
        pd.decorations = [DecorationDesc.none]         
        product.xpath('decorations/decoration').each do |decoration|
          technique = decoration["technique"]
          if @@decoration_replace[technique]
            technique, limit = @@decoration_replace[technique]
          else
            warning 'UNKNOWN DECORATION', technique
            next
          end
          
          decoration.elements.each do |location|
            dd = DecorationDesc.new(:technique => technique,
                                    :limit => limit)
            
            if area = parse_area(s = location.text.strip)
              dd.location = ((area.delete(:left) || '') + ' ' + (area.delete(:right) || '')).strip
              dd.merge!(area)
            else
              dd.location = s
              warning 'Unknown location', s
            end

            pd.decorations << dd
          end
        end
        
        # related-products?
  
        prod_categories = nil
        
        # items
        xml_items = product.xpath('items/item')
        pd.properties['material'] = xml_items.first && xml_items.first['fabric'] # Kludge to assume same material for all variants
        
        has_swatch = nil
        pd.variants = xml_items.collect do |item|
          vd = VariantDesc.new(:supplier_num => item['style'])
          vd.properties['color'] = item['color'] || 'UNKNOWN'
          
          if swatch_node = item.at_xpath('swatches/image')
            vd.properties['swatch'] = ImageNodeFetch.new(swatch_node['name'].split('.').first, "#{swatch_node['path']}#{swatch_node['name']}")
            has_swatch = true
          end
          
          image_node = item.at_xpath('images/zoomed')
          image_node = item.at_xpath('images/enlarged') unless image_node
          if image_node
            vd.images = [ImageNodeFetch.new(image_node['name'], "#{image_node['path']}#{image_node['name']}")]
            
            puts item.inspect if pd.supplier_num == '2825'
            item.at_xpath('images/alternate-images').try do |element|
              element.children.each do |alt|
                if /zoomed(\d)/ === alt.name
                  vd.images << ImageNodeFetch.new("alts/#{alt['name']}", "#{alt['path']}#{alt['name']}".gsub('\\','/'))
                end
              end
            end
            vd.images.uniq!
          end
          
          last_max = nil
          item.xpath("pricing[@type='US']/price").each do |price|
            unless /^(?<min>\d+)[-+](?<max>\d+)?$/ =~ price['break']
              raise PropertyError.new('Unknown break', price['break'])
            end
            warning 'Non contigious prices' if last_max and min.to_i != last_max + 1
            last_max = max && max.to_i
            vd.pricing.add(min, price.text, price['code'], true)
          end
          vd.pricing.eqp_costs  # We have end quantity pricing with this supplier
          vd.pricing.ltm(60.00) # http://www.gemline.com/Gemline/services/index.aspx?id=140  $75(G) cost is $75*0.8=$60
          
          categories = parse_categories(item.at_xpath('categories'))
          collections = item.at_xpath('collections')
          categories += parse_categories(collections).collect { |e| ['Collections'] + e }
          if prod_categories
            if prod_categories != categories
              raise "Inconsistent categories: #{prod_categories.inspect} != #{categories.inspect}"
            end
          else
            prod_categories = categories.uniq
          end
          
          vd
        end.compact

        # Kludge to remove swatch if one swatch is missing, only known to happen on product 2361
        if has_swatch && pd.variants.find { |vd| !vd.properties.has_key?('swatch') }
          warning 'REMOVED SWATCH'
          pd.variants.each do |vd|
            vd.properties.delete('swatch')
          end
        end
        
        # Apply uses in XML as category
        prod_categories ||= []
        if uses = product.xpath('product-uses/uses')
          prod_categories += uses.collect { |use| ['Uses', use['name']] }
        end
               

        # Turn closeout/new category to tag
        prod_categories.delete_if do |category|
          delete = nil
          { 'Clearance' => 'Closeout',
            'New Products' => 'New',
            'Eco-Choice' => 'Eco' }.each do |cat, tag|
            if category.include?(cat)
              pd.tags << tag unless pd.tags.include?(tag)
            delete = true
            end
          end
          delete
        end
        pd.supplier_categories = prod_categories

        # Set as special if one of the variants only has one price
        if !pd.tags.include?('Closeout') and
            pd.variants.find { |vd| vd.pricing.prices.length == 1 }
          pd.tags << 'Special'
        end

        # Set maximum quantity based on max of all variants
        maximum = pd.variants.collect { |vd| vd.pricing.max_default_qty }.max
        pd.variants.each { |vd| vd.pricing.maxqty(maximum)}
    
      end # ProductDesc
    end # gemroot.each_element
  end
end
