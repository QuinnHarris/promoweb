# Starline API documented at http://www.starline.com/WebService/Catalog.asmx

class Starline < GenericImport
  @@decoration_replace = {
    'Silkscreen' => 'Screen Print',
    'Embroidery' => 'Embroidery',
    'Pad Printing' => 'Pad Print',
    'Deboss' => 'Deboss',
    'Laser Engraving' => 'Laser Engrave'
  }

  def initialize
    super "Starline"
  end

  # No fetch_parse?
  
  def get_method(name, params = nil)
    tail = params && ('?' + params.collect { |k, v| "#{k}=#{v}" }.join('&'))
    doc = WebFetch.new("http://www.starline.com/WebService/Catalog.asmx/#{name}#{tail}").get_doc
    raise ValidateError.new("Method Failed", "#{name} : #{params.inspect}") unless doc
    doc
  end

  # Called to do the actual work
  def parse_products
    product_list = []
    # Fetch First level categories
    puts 'Fetching Product List'
    get_method('getCategories').xpath('//newdataset/category').each do |cat|
      cat_id = cat.at_xpath('categoryid/text()').to_s
      cat_name = cat.at_xpath('category/text()').to_s.gsub('&amp;', '&')
      puts "  #{cat_name} : #{cat_id}"

      # Fetch Second level categories
      get_method('getSubCategories', 'CategoryID' => cat_id).xpath('//newdataset/subcategory').each do |cat|
        subcat_id = cat.at_xpath('subcategoryid/text()').to_s
        subcat_name = cat.at_xpath('subcategory/text()').to_s.gsub('&amp;', '&')
        puts "    #{subcat_name} : #{subcat_id}"
        get_method('getProducts', 'SubCategoryID' => subcat_id).xpath('//newdataset/product').each do |prod|
          product_list << ProductDesc.new(:supplier_num => prod.at_xpath('productid/text()').to_s,
                                          :data => { :id => prod.at_xpath('itemno/text()').to_s.to_i },
                                          :name => prod.at_xpath('product/text()').to_s,
                                          :supplier_categories => [[cat_name, subcat_name]])
        end
      end
    end

    puts "Product Count: #{product_list.length}"
    product_list.each do |pd|
      ProductDesc.apply(self, pd) do |pd|
        id = pd.data[:id]
        file = WebFetch.new("http://us.starline.com/translations/catalog/products/en-us/us/#{id}.json").get
        next unless file
        response = MultiJson.load(file)
        
        pd.description = response['description']        

        # Shipping Info
        if shippingInfo = response['shippingInfo']
          pd.package.length = shippingInfo['length']
          pd.package.width  = shippingInfo['width']
          pd.package.height = shippingInfo['height']
          pd.package.units  = shippingInfo['piecesPerBox']
          pd.package.weight = shippingInfo['weightPerBox']
        end
                  
        # Dimension
        dimension = response['size']
        dimension.delete_if { |k, v| v == 0.0 }
        pd.properties['dimension'] = dimension.empty? ? nil : dimension


        # Decorations (needs pricing)
        pd.decorations = [DecorationDesc.none]
        response["imprints"].each do |imprint_method|
          if technique = @@decoration_replace[imprint_method['name']]
            imprint_method["location"].each do |method|
              pd.decorations << DecorationDesc.new(:technique => technique,
                                                   :location => method["name"],
                                                   :height => method["height"],
                                                   :width => method["width"])
            end
          else
            warning 'Unknown Decoration', imprint_method['name']
          end
        end


        # Tags
        pd.tags = []
        pd.tags << 'Closeout' if response['closeout']
        if response['types'] && response['types'].find { |h| h['name'].include?('New') } or
            response['logos'] && response['logos'].find { |h| h['name'] == '119' }
          pd.tags << 'New'
        end


        # All product image file names
        image_files = response['carouselImages'].collect do |file|
          file.gsub(/^cs_/, 'lg_')
        end

        # Pricing
        if pri = response['printed']
          if response['types'] && response['types'].find { |h| h['name'] == 'Special Printed' }
            pd.tags << 'Special' unless pd.tags.include?('New')
            pri = response['specialPrinted']
          end

          # Pricing
          pri['qty'].zip(pri['price']).each do |qty, cost|
            next if cost.nil? or cost == 0.0
            
            # the price field is actually the cost of the item
            pd.pricing.add(qty, nil, cost)
          end
          pd.pricing.apply_code(response['priceCode'], :reverse => true, :fill => true)
          pd.pricing.ltm(32.0)
          pd.pricing.maxqty

          # Variants
          colors = response['colors']
          if colors.empty?
            pd.variants = [VariantDesc.new(:supplier_num => pd.supplier_num, :properties => {}, :images => [])]
          else
            colors.each do |color|
              if pd.variants.find { |vd| vd.properties['color'] == color['name'] }
                warning 'Duplicate Color', color['name']
                next
              end

              # Find matching images and place in this variant
              images = image_files.find_all { |f| f.include?("_#{color['code']}") }
              image_files -= images
              
              pd.variants <<
                VariantDesc.new(:supplier_num => pd.supplier_num + color['name'],
                                :properties => { 'color' => color['name'] },
                                :images => images.collect { |f| ImageNodeFetch.new(f, "http://us.starline.com/content/image/product/#{f}") })
            end
          end
        elsif list = response['magnetPricing']
          raise "Unexpected colors" unless response['colors'].empty?

          list.each do |hash|
            properties = { 'size' => hash['size'], 'type' => hash['type'] }
            if pd.variants.find { |vd| vd.properties == properties }
              warning 'Duplicate Magnet', properties.inspect
              next
            end

            vd = VariantDesc.new(:supplier_num => hash['code'],
                                 :properties => properties,
                                 :images => [])
            (1..4).each do |n|
              vd.pricing.add(hash["qty#{n}"], nil, hash["price#{n}"])
            end
            vd.pricing.apply_code(response['priceCode'], :reverse => true, :fill => true)
            vd.pricing.ltm(32.0)
            vd.pricing.maxqty
            pd.variants << vd
          end
        else
          raise ValidateError, 'No Pricing'
        end


        pd.images = image_files.collect { |f| ImageNodeFetch.new(f, "http://us.starline.com/content/image/product/#{f}") }


        response["specs"].each do |specs|
          name = specs['header']
          text = specs['text']
          case name
          when 'Packaging', 'Insulation Type', 'Mug Liner' 
            pd.properties[name] = text.gsub(/<.+?\/?>/, '').strip

          when 'Band Colors'
            pd.variants = pd.variants.collect do |vd|
              text.split(/\s*,\s*/).collect do |color|
                vd = vd.dup
                vd.supplier_num = pd.supplier_num + color
                vd.properties[name] = color
                vd
              end
              
            end.flatten
          when 'Price', 'Set-Up Charge', 'More Info', 'Oxidation'

          else
            warning 'Unknown Spec', specs["header"]
          end

        end

      end # ProductDesc.apply
    end # product_list.each
  end # parse_products
end
