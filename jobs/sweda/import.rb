require 'csv'

class SwedaXML < GenericImport
  def initialize
    @src_urls = ['http://www.swedausa.com/Main/default/HandlerCSVFile.ashx']
    super 'Sweda'
  end

#  Specification Note RequestSample RelatedProducts TubeVideo SlideShow Thumbnail Image PdfFiles AdditionalImages MetaTitle MetaDesc MetaKeywords MetaPriority MetaPostDate ApplicationID ProductionTime ImprintArea VirtualLogo ApplicationName CloseOut BestSell NewArrive DisplayProduct IsSampleRequest Qty_Desc Qty_DisplayPoint1 Qty_Point1 Qty_Price1 Qty_Special1 Qty_DisplayPoint2 Qty_Point2 Qty_Price2 Qty_Special2 Qty_DisplayPoint3 Qty_Point3 Qty_Price3 Qty_Special3 Qty_DisplayPoint4 Qty_Point4 Qty_Price4 Qty_Special4 Qty_DisplayPoint5 Qty_Point5 Qty_Price5 Qty_Special5 Qty_DisplayPoint6 

  # Ignore: ProductId SizeCode SizeDesc MaxOrder AdditionalPrice GrossWeight Qty_Point6 Qty_Price6 Qty_Special6 Qty_Col1Name Qty_Col1Price1 Qty_Col1Price2 Qty_Col1Price3 Qty_Col1Price4 Qty_Col1Price5 Qty_Col1Price6 Qty_Col2Name Qty_Col2Price1 Qty_Col2Price2 Qty_Col2Price3 Qty_Col2Price4 Qty_Col2Price5 Qty_Col2Price6 Qty_Col3Name Qty_Col3Price1 Qty_Col3Price2 Qty_Col3Price3 Qty_Col3Price4 Qty_Col3Price5 Qty_Col3Price6

  def parse_products
    unique_columns = %w(Sku ColorCode ColorDesc ColorSwatch VariantImage)
    # SizeCode SizeDesc GrossWeight
    common_columns = %w(AdditionalPrice ItemNo ProductName Description Specification Note RequestSample RelatedProducts TubeVideo SlideShow Thumbnail Image PdfFiles AdditionalImages MetaTitle MetaDesc MetaKeywords MetaPriority MetaPostDate ApplicationID ProductionTime ImprintArea VirtualLogo PackQty PackWeight ProductionMinTime ProductionMaxTime MaxOrder ApplicationName CATEGORY_NAME CloseOut BestSell NewArrive DisplayProduct IsSampleRequest Qty_Desc Qty_DisplayPoint1 Qty_Point1 Qty_Price1 Qty_Special1 Qty_DisplayPoint2 Qty_Point2 Qty_Price2 Qty_Special2 Qty_DisplayPoint3 Qty_Point3 Qty_Price3 Qty_Special3 Qty_DisplayPoint4 Qty_Point4 Qty_Price4 Qty_Special4 Qty_DisplayPoint5 Qty_Point5 Qty_Price5 Qty_Special5 Qty_DisplayPoint6 Qty_Point6 Qty_Price6 Qty_Special6 Qty_Col1Name Qty_Col1Price1 Qty_Col1Price2 Qty_Col1Price3 Qty_Col1Price4 Qty_Col1Price5 Qty_Col1Price6 Qty_Col2Name Qty_Col2Price1 Qty_Col2Price2 Qty_Col2Price3 Qty_Col2Price4 Qty_Col2Price5 Qty_Col2Price6 Qty_Col3Name Qty_Col3Price1 Qty_Col3Price2 Qty_Col3Price3 Qty_Col3Price4 Qty_Col3Price5 Qty_Col3Price6)
    product_merge = ProductRecordMerge.new(unique_columns, common_columns)

    CSV.foreach(@src_files.first, :headers => :first_row) do |row|
      product_merge.merge(row['ItemNo'], row, :allow_dup => true)
    end

    product_merge.each do |supplier_num, unique, common|
      ProductDesc.apply(self) do |pd|
        pd.supplier_num = supplier_num
        pd.name = common['ProductName']
        pd.description = common['Description'].gsub('&nbsp;', ' ').split(/\s*[;\.!\n]\s*(?=[A-Z])/)
        pd.supplier_categories = common['CATEGORY_NAME'].split(";").collect { |s| s.split("\\").collect { |t| t.strip } }

        pd.tags << 'Closeout' if pd.supplier_categories.find { |c| c.shift if c.first == 'Clearance' }
        pd.tags << 'New' if pd.supplier_categories.find { |c| c.include?('2014 New Items') }
      
        if Integer(common['PackQty']) > 0 and Float(common['PackWeight']) > 0.0
          pd.package.units = common['PackQty']
          pd.package.weight = common['PackWeight']
        end

        min, max = %w(Min Max).collect { |s| (v = common["Production#{s}Time"]) && (i = Integer(v); i > 0 ? i : nil) }
        pd.lead_time.normal_min = min || max
        pd.lead_time.normal_max = max || min


        (1..6).each do |i|
          qty = common["Qty_Point#{i}"]
          break if qty.blank? or qty == '0'
          if (price = Float(common["Qty_Special#{i}"])) == 0.0
            price = common["Qty_Price#{i}"]
          end
          pd.pricing.add(qty, price, 'R')
        end
        pd.pricing.maxqty
        # LTM?

        str = common['Specification'].gsub('&nbsp;', ' ').strip
        puts "Orig: #{supplier_num} #{str.inspect}"
        str.scan(/^\s*([\w\s]+?)\s*:\s*(.+?)\s*$/m).each do |key, value|
          puts "  #{key}: #{value}"
        end

        pd.decorations = [DecorationDesc.none]

        { 'screen' => 'Screen Print',
          'laser' => 'Laser Engrave' }.each do |match, tech|
          next unless common['Specification'].downcase.include?(match)
          pd.decorations << DecorationDesc.new(:technique => tech,
                                               :location => '')
        end

        images = []
        { 'LargeImg' => [common['Image']],
          'AdditionalImg' => common['AdditionalImages'].split(';')
        }.each do |path_sub, list|
          images += list.collect do |img|
            unless /^#{supplier_num}[-_]?(.*?)(?:-[15]{2,3}x)?\.jpg$/i === img
              puts "Unknown Image: #{supplier_num} #{img.inspect}"
              tail = img
              next if img[0] == '.'
            else
              tail = $1
            end
            
            [ImageNodeFetch.new(img,
                                "http://www.swedausa.com/Uploads/Products/#{path_sub}/#{img.gsub('[','%5B').gsub(']','%5D')}"), tail]
          end.compact.uniq
        end
     
        colors = unique.collect { |u| u['ColorCode'] }
        color_image_map, color_num_map = match_image_colors(images, colors, :prune_colors => true)
        pd.images = color_image_map[nil] || []

        pd.variants = unique.collect do |uniq|
          VariantDesc.new(:supplier_num => uniq['Sku'],
                          :properties => { 'color' => uniq['ColorDesc'].blank? ? nil : uniq['ColorDesc'].strip },
                          :images => color_image_map[uniq['ColorCode']] || [])
        end
      end
    end
  end
end
