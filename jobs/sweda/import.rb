require 'csv'

class SwedaXML < GenericImport
  def initialize
    time = Time.now - 1.day
    @src_file = WebFetch.new('http://www.swedausa.com/Main/default/HandlerCSVFile.ashx').get_path(time)
    super 'Sweda'
  end

#  Specification Note RequestSample RelatedProducts TubeVideo SlideShow Thumbnail Image PdfFiles AdditionalImages MetaTitle MetaDesc MetaKeywords MetaPriority MetaPostDate ApplicationID ProductionTime ImprintArea VirtualLogo ApplicationName CloseOut BestSell NewArrive DisplayProduct IsSampleRequest Qty_Desc Qty_DisplayPoint1 Qty_Point1 Qty_Price1 Qty_Special1 Qty_DisplayPoint2 Qty_Point2 Qty_Price2 Qty_Special2 Qty_DisplayPoint3 Qty_Point3 Qty_Price3 Qty_Special3 Qty_DisplayPoint4 Qty_Point4 Qty_Price4 Qty_Special4 Qty_DisplayPoint5 Qty_Point5 Qty_Price5 Qty_Special5 Qty_DisplayPoint6 

  # Ignore: ProductId SizeCode SizeDesc MaxOrder AdditionalPrice GrossWeight Qty_Point6 Qty_Price6 Qty_Special6 Qty_Col1Name Qty_Col1Price1 Qty_Col1Price2 Qty_Col1Price3 Qty_Col1Price4 Qty_Col1Price5 Qty_Col1Price6 Qty_Col2Name Qty_Col2Price1 Qty_Col2Price2 Qty_Col2Price3 Qty_Col2Price4 Qty_Col2Price5 Qty_Col2Price6 Qty_Col3Name Qty_Col3Price1 Qty_Col3Price2 Qty_Col3Price3 Qty_Col3Price4 Qty_Col3Price5 Qty_Col3Price6

  def parse_products
    unique_columns = %w(Sku ColorCode ColorDesc ColorSwatch VariantImage)
    common_columns = %w(SizeCode SizeDesc AdditionalPrice GrossWeight ItemNo ProductName Description Specification Note RequestSample RelatedProducts TubeVideo SlideShow Thumbnail Image PdfFiles AdditionalImages MetaTitle MetaDesc MetaKeywords MetaPriority MetaPostDate ApplicationID ProductionTime ImprintArea VirtualLogo PackQty PackWeight ProductionMinTime ProductionMaxTime MaxOrder ApplicationName CATEGORY_NAME CloseOut BestSell NewArrive DisplayProduct IsSampleRequest Qty_Desc Qty_DisplayPoint1 Qty_Point1 Qty_Price1 Qty_Special1 Qty_DisplayPoint2 Qty_Point2 Qty_Price2 Qty_Special2 Qty_DisplayPoint3 Qty_Point3 Qty_Price3 Qty_Special3 Qty_DisplayPoint4 Qty_Point4 Qty_Price4 Qty_Special4 Qty_DisplayPoint5 Qty_Point5 Qty_Price5 Qty_Special5 Qty_DisplayPoint6 Qty_Point6 Qty_Price6 Qty_Special6 Qty_Col1Name Qty_Col1Price1 Qty_Col1Price2 Qty_Col1Price3 Qty_Col1Price4 Qty_Col1Price5 Qty_Col1Price6 Qty_Col2Name Qty_Col2Price1 Qty_Col2Price2 Qty_Col2Price3 Qty_Col2Price4 Qty_Col2Price5 Qty_Col2Price6 Qty_Col3Name Qty_Col3Price1 Qty_Col3Price2 Qty_Col3Price3 Qty_Col3Price4 Qty_Col3Price5 Qty_Col3Price6)
    product_merge = ProductRecordMerge.new(unique_columns, common_columns)

    CSV.foreach(@src_file, :headers => :first_row) do |row|
      product_merge.merge(row['ItemNo'], row, true)
    end

    product_merge.each do |supplier_num, unique, common|
      product_data = {
        'supplier_num' => supplier_num,
        'name' => common['ProductName'],
        'description' => common['Description'].gsub('&nbsp;', ' ').split(/\s*[;\.!\n]\s*(?=[A-Z])/).join("\n"),
        'supplier_categories' => common['CATEGORY_NAME'].split(";").collect { |s| s.split("\\").collect { |t| t.strip } },
        'tags' => []
      }
      if product_data['supplier_categories'].find { |c| c.shift if c.first == 'CLEARANCE'  }
        product_data['tags'] << 'Closeout'
      end
      product_data['tags'] << 'New' if product_data['supplier_categories'].find { |c| c.include?('2012 New Items') }
      
      { 'PackQty' => 'package_units',
        'PackWeight' => 'pacakge_weight',
        'ProductionMinTime' => 'lead_time_normal_min',
        'ProductionMaxTime' => 'lead_time_normal_max',
      }.each do |row_name, prop_name|
        product_data[prop_name] = common[row_name].include?('.') ? Float(common[row_name]) : Integer(common[row_name]) unless common[row_name].blank? || common[row_name] == '0'
      end
      product_data['lead_time_normal_max'] ||= product_data['lead_time_normal_min']
      product_data['lead_time_normal_min'] ||= product_data['lead_time_normal_max']

      common_variant = SupplierPricing.get do |pricing|
        (1..6).each do |i|
          qty = common["Qty_Point#{i}"]
          break if qty.blank? or qty == '0'
          if (price = Float(common["Qty_Special#{i}"])) == 0.0
            price = common["Qty_Price#{i}"]
          end
          pricing.add(qty, price, 'R')
        end
        pricing.maxqty
      end

#      str = common['Specification'].gsub('&nbsp;', ' ').strip
#      puts "Orig: #{supplier_num} #{str.inspect}"
#      str.scan(/^\s*([\w\s]+?)\s*:\s*(.+?)\s*$/).each do |key, value|
#        puts "  #{key}: #{value}"
#      end


      decorations = [{
                       'technique' => 'None',
                       'location' => ''
                     }]
      { 'screen' => 'Screen Print',
        'laser' => 'Laser Engrave' }.each do |match, tech|
        decorations << { 'technique' => tech,
          'location' => '' } if common['Specification'].downcase.include?(match)
      end
      product_data['decorations'] = decorations

      images = []
      { 'LargeImg' => [common['Image']],
        'AdditionalImg' => common['AdditionalImages'].split(';')
      }.each do |path_sub, list|
        images += list.collect do |img|
          unless Regexp.new("^#{supplier_num}[-_]?(.*?)(?:-[15]{2,3}x)?\.jpg$", Regexp::IGNORECASE) === img
            puts "Unkown Image: #{supplier_num} #{img.inspect}"
            tail = img
          else
            tail = $1
          end

          [ImageNodeFetch.new(img,
                              "http://www.swedausa.com/Uploads/Products/#{path_sub}/#{img.gsub('[','%5B').gsub(']','%5D')}"), tail]
        end
      end
      
      colors = unique.collect { |u| u['ColorCode'] }
      color_image_map, color_num_map = match_image_colors(images, colors, supplier_num)
      product_data['images'] = color_image_map[nil]

      product_data['variants'] = unique.collect do |uniq|
        { 'supplier_num' => uniq['Sku'],
          'properties' => { 'color' => uniq['ColorDesc'].blank? ? nil : uniq['ColorDesc'].strip },
          'images' => color_image_map[uniq['ColorCode']],
        }.merge(common_variant)
      end

      add_product(product_data)
    end
  end
end
