# Starline API documented at http://www.starline.com/WebService/Catalog.asmx

class Starline < GenericImport
  include HTTParty
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
    product_list.each_with_index do |pd,index|
      ProductDesc.apply(self, pd) do |pd|
        id = pd.data[:id]
        response = HTTParty.get("http://us.starline.com/translations/catalog/products/en-us/us/#{id}.json")  
        
        pd.description = response['description'].join("\n")

        images = []

        images << "lg_#{id}.jpg"
        pd.images = [ImageNodeFetch.new('main', "http://us.starline.com/content/image/product/lg_#{id}.jpg")]
        
        #getProductShippingInfo : Good and complete
        shippingInfo = response['shippingInfo']
        pd.package.length = shippingInfo['length'].to_f  
        pd.package.width  = shippingInfo['width'].to_f
        pd.package.height = shippingInfo['height'].to_f  
        pd.package.units  = shippingInfo['piecesPerBox'].to_f  
        pd.package.weight = shippingInfo['weightPerBox'].to_f 
        
        #getCodedPriceChartUS
        printed = response['printed']
        printed['qty'].each_with_index do |qty,index|
          pd.pricing.add(qty.to_f, printed['price'][index].to_f)
        end
        pd.pricing.apply_code(response['priceCode'].to_s) # Added to use 
        pd.pricing.ltm(32.0) # Less than minimum charge, had to look up in PDF catalog on website
        pd.pricing.maxqty # Should apply to most pricing

        pd.properties['dimension'] = response['size']

        

        # Complete by adding a DecoratonDesc object for each combination of "Imprint Method(s)"
        pd.decorations = [DecorationDesc.none]
        response["imprints"].each do |imprint_method|
          if @@decoration_replace[imprint_method['name']]
             technique = @@decoration_replace[imprint_method['name']]
             imprint_method["location"].each do |method|
                 dd = DecorationDesc.new({:technique => technique,:location=>method["name"].to_s,:height=>method["height"],:width=>method["width"]})
               pd.decorations << dd
             end
          else
              warning 'UNKNOWN DECORATION', technique
          end  
        end   

        pd.tags = []  

        response['colors'].each do |color|
           image_node = "lg_#{id}_#{color['code']}.jpg"
           vd = VariantDesc.new(:supplier_num => pd.supplier_num + color['name'],
                :properties => { 'color' => color['name'] },:images=>[ImageNodeFetch.new('main', "http://us.starline.com/content/image/product/#{image_node}")])
           pd.variants << vd
           images << image_node 
        end  


        response["specs"].each do |specs|
            name = specs["header"]
            case name
              when 'Packaging'
              when 'Price'
              when 'Set-Up Charge' 
              when 'More Info' 
              when 'Oxidation'
              when 'Insulation Type' 
              when 'Mug Liner' 
                puts "specification : #{name} " 
                pd.properties[name] = specs["text"] 
              when 'Band Colors'
                band_colors = []
                band_colors = specs["text"].split(",") 
                response["carouselImages"].each_with_index do |image_small,index|
                  image_large = image_small.gsub!("cs","lg")
                  if !images.include?(image_large) && !band_colors[index].nil?
                    vd = VariantDesc.new(:supplier_num => pd.supplier_num + image_large ,:properties => { 'color' =>band_colors[index]  },:images=>[ImageNodeFetch.new('main', "http://us.starline.com/content/image/product/#{image_large}")])
                    pd.variants << vd
                    images << image_large
                  end
                end
              else
              # Warnings will be summarised at the end.  Quick way to determine all unknown properties
              warning 'Unknown Spec', specs["header"]
            end
        end
      end
    end
  end
end
