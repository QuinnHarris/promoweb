# Starline API documented at http://www.starline.com/WebService/Catalog.asmx

class Starline < GenericImport
  @@decoration_replace = { 'Silkscreen' => 'Screen Print',
  'Embroidery' => 'Embroidery',
  'Embroider' => 'Embroidery',
  'Pad Printing' => 'Pad Print',
  'Deboss' => 'Deboss',
  'Laser Engraving' => 'Laser Engrave'}

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
      cat_name = cat.at_xpath('category/text()').to_s
      puts "  #{cat_name} : #{cat_id}"

      # Fetch Second level categories
      get_method('getSubCategories', 'CategoryID' => cat_id).xpath('//newdataset/subcategory').each do |cat|
        subcat_id = cat.at_xpath('subcategoryid/text()').to_s
        subcat_name = cat.at_xpath('subcategory/text()').to_s
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
        
        # Pricing (What about magnet pricing)
        if printed = response['printed']
          printed['qty'].zip(printed['price']).each do |qty, cost|
            # the price field is actually the cost of the item
            pd.pricing.add(qty, nil, cost)
          end
          pd.pricing.apply_code(response['priceCode'], :reverse => true, :fill => true) # :reve
          pd.pricing.ltm(32.0) # Less than minimum charge, had to look up in PDF catalog on website
          pd.pricing.maxqty # Should apply to most pricing
        end
          
        pd.properties['dimension'] = response['size']

        

        # Complete by adding a DecoratonDesc object for each combination of "Imprint Method(s)"
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
            warning 'UNKNOWN DECORATION', technique
          end
        end

        pd.tags = []
        pd.tags << 'Closeout' if response['closeout']

        # All product image file names
        image_files = response['carouselImages'].collect do |file|
          file.gsub(/^cs_/, 'lg_')
        end

        response['colors'].each do |color|
          images = image_files.find_all { |f| f.include?("_#{color['code']}") }
          image_files -= images

          vd = VariantDesc.new(:supplier_num => pd.supplier_num + color['name'],
                               :properties => { 'color' => color['name'] },
                               :images => images.collect { |f| ImageNodeFetch.new(f, "http://us.starline.com/content/image/product/#{f}") })
          pd.variants << vd
        end  

        pd.images = image_files.collect { |f| ImageNodeFetch.new(f, "http://us.starline.com/content/image/product/#{f}") }


        response["specs"].each do |specs|
          name = specs['header']
          text = specs['text']
          case name
          when 'Packaging', 'Insulation Type'
            pd.properties[name] = text.gsub(/<.+?\/?>/, '')
          when 'Price'
          when 'Set-Up Charge' 
          when 'More Info' 
          when 'Oxidation'
          when 'Mug Liner' 
            puts "specification : #{name} " 
            pd.properties[name] = specs["text"] 
#          when 'Band Colors'
#            band_colors = []
#            band_colors = specs["text"].split(",") 
#            response["carouselImages"].each_with_index do |image_small,index|
#              image_large = image_small.gsub!("cs","lg")
#              if !images.include?(image_large) && !band_colors[index].nil?
#                vd = VariantDesc.new(:supplier_num => pd.supplier_num + image_large ,:properties => { 'color' =>band_colors[index]  },:images=>[ImageNodeFetch.new('main', "http://us.starline.com/content/image/product/#{image_large}")])
#                pd.variants << vd
#              end
#                end
          else
            # Warnings will be summarised at the end.  Quick way to determine all unknown properties
              warning 'Unknown Spec', specs["header"]
          end

        end

      end # ProductDesc.apply
    end # product_list.each
  end # parse_products
end
