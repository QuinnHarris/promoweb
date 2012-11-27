# Starline API documented at http://www.starline.com/WebService/Catalog.asmx

class Starline < GenericImport
  @@decoration_replace = { 'Silkscreen' => 'Screen Print',
  'Embroidery' => 'Embroidery',
  'Embroider' => 'Embroidery',
  'Pad Print' => 'Pad Printing',
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

        # Fetch each product in the subcategory and place associated ProductDesc object in product_list
        get_method('getProducts', 'SubCategoryID' => subcat_id).xpath('//newdataset/product').each do |prod|
          product_list << ProductDesc.new(:supplier_num => prod.at_xpath('productid/text()').to_s,
                                          :data => { :id => prod.at_xpath('itemno/text()').to_s.to_i },
                                          :name => prod.at_xpath('product/text()').to_s,
                                          :supplier_categories => [[cat_name, subcat_name]])
        end
      end
    end

    puts "Product Count: #{product_list.length}"
    
    product_list.each_with_index do |pd,index|
      ProductDesc.apply(self, pd) do |pd|
        id = pd.data[:id]
        pd.description =
          get_method('getProductDescription', 'ItemNo' => id)
          .xpath('//desc/description/text()').collect { |t| t.to_s }

        pd.images = [ImageNodeFetch.new('main', "http://us.starline.com/content/image/product/lg_#{id}.jpg")]
        
        #getProductShippingInfo : Good and complete
        proshiping = get_method('getProductShippingInfo', 'ItemNo' => id)
        pd.package.length = proshiping.at_xpath('//shippinginfo/length/text()').to_s.to_f
        pd.package.width = proshiping.at_xpath('//shippinginfo/width/text()').to_s.to_f
        pd.package.height = proshiping.at_xpath('//shippinginfo/height/text()').to_s.to_f
        pd.package.units = proshiping.at_xpath('//shippinginfo/pcbx/text()').to_s.to_i
        pd.package.weight = proshiping.at_xpath('//shippinginfo/lbs_bx/text()').to_s.to_f
        
        #getCodedPriceChartUS
        pricechart = get_method('getCodedPriceChartUS', 'ItemNo' => id).xpath("//newdataset/chart")
        (1..4).each do |i|
          qty = pricechart.at_xpath("nqty#{i}/text()").to_s.to_i
          price = pricechart.at_xpath("nprice#{i}/text()").to_s
          pd.pricing.add(qty, price)
        end
        pd.pricing.apply_code(pricechart.at_xpath('pricecode/text()').to_s) # Added to use 
        pd.pricing.ltm(32.0) # Less than minimum charge, had to look up in PDF catalog on website
        pd.pricing.maxqty # Should apply to most pricing

        colors = [nil]
        imprint_methods = imprint_areas = []
        spefs_hash = {}
        get_method('getSpefs', 'ItemNo' => id).xpath('//newdataset/spef').each do |spec|
          name = spec.at_xpath('specification/text()').to_s
          data = spec.at_xpath('specificationdata/text()').to_s

          case name
            when 'Product Color'
            colors = data.split(/\s*,\s*/)
            
            when 'Product Size'
            pd.properties['dimension'] = parse_dimension(data)
            
            when 'Imprint Method(s)'
            # data is starlines own techniques.
            imprint_methods = data.split(/\s*,\s*/)
            imprint_methods.each do |method|
              warning "Unknown method", method
            end
            
            when 'Imprint Area(s)'
            imprint_areas = data.split(/\s*,\s*/).collect { |a| parse_dimension(a) }.compact

            when 'Packaging'
             pd.properties[name] = data

            when 'Note'
             pd.description = pd.description.to_s + data.to_s 

            else
            # Warnings will be summarised at the end.  Quick way to determine all unknown properties
            warning 'Unknown Spec', name
          end

          spefs_hash[name] = data
        end
        #getAddons
        #getGroupSpefs

        pd.decorations = [DecorationDesc.none]
        pd.tags = []

        # Complete by adding a DecoratonDesc object for each combination of "Imprint Method(s)" and "Imprint Area(s)"

        imprint_methods.each do |method|
          if @@decoration_replace[method]
             technique = @@decoration_replace[method]
             dd = DecorationDesc.new({:technique => technique,:location=>''}.merge!(imprint_areas.first))
             pd.decorations << dd
          else
              warning 'UNKNOWN DECORATION', technique
          end  
        end  

        pd.variants = colors.collect do |color|
           VariantDesc.new(:supplier_num => pd.supplier_num + color,
                          :properties => { 'color' => color },:images=>[])
        end
        
      end
    end
  end
end
