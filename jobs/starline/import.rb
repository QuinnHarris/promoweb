# Starline API documented at http://www.starline.com/WebService/Catalog.asmx

class Starline < GenericImport
  def initialize
    super "Starline"
  end

  # No fetch_parse?
  
  def get_method(name, params = nil)
    tail = params && ('?' + params.collect { |k, v| "#{k}=#{v}" }.join('&'))
    WebFetch.new("http://www.starline.com/WebService/Catalog.asmx/#{name}#{tail}").get_doc
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
    
    product_list.each do |pd|
      ProductDesc.apply(self, pd) do |pd|
        id = pd.data[:id]
        pd.description =
          get_method('getProductDescription', 'ItemNo' => id)
          .xpath('//desc/description/text()').collect { |t| t.to_s }

        #getProductShippingInfo  
        proshiping = get_method('getProductShippingInfo', 'ItemNo' => id)
        pd.package.length = proshiping.at_xpath('//shippinginfo/length/text()').to_s.to_f
        pd.package.width = proshiping.at_xpath('//shippinginfo/width/text()').to_s.to_f
        pd.package.height = proshiping.at_xpath('//shippinginfo/height/text()').to_s.to_f
        pd.package.units = proshiping.at_xpath('//shippinginfo/pcbx/text()').to_s.to_i
        pd.package.weight = proshiping.at_xpath('//shippinginfo/lbs_bx/text()').to_s.to_f
        #getCodedPriceChartUS
        pricechart = get_method('getCodedPriceChartUS', 'ItemNo' => id).xpath("//newdataset/chart")
        (1..4).each do |i|
         pricing = PricingDesc.new 
         qty = pricechart.at_xpath("nqty#{i}/text()").to_s.to_i
         price = pricechart.at_xpath("nprice#{i}/text()").to_s
         pricing.add(qty, price)
        end

        spefs_hash = {}
        get_method('getSpefs', 'ItemNo' => id).xpath('//newdataset/spef').each do |spec|
          name = spec.at_xpath('specification/text()').to_s
          data = spec.at_xpath('specificationdata/text()').to_s
          spefs_hash[name] = data
        end  
        pd.properties = {
          'dimension' => parse_dimension(spefs_hash['Product Size']) 
        }
        puts "Area: #{spefs_hash['Imprint Area(s)']}"
        locations = parse_areas(spefs_hash['Imprint Area(s)'])
        locations.each do |imprint|
          puts "  #{imprint.inspect}"
        end
        # Imprint method(s) 
        spefs_hash['Imprint Area(s)'].split(",").each do |technique|
          dec = DecorationDesc.new(:technique => technique,:location => "",:limit => "")
          pd.decorations << dec
        end
        
        #getGroupSpefs
      end
    end
  end
end
