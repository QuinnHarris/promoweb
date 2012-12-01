# ToDO
# Quantity on decoration pricing

class AdbagProdXLS < GenericImport
  @@decoration_replace = {
    'SILK SCREEN' => 'Screen Print',
    'FLEXOGRAPHIC' => 'FLEXOGRAPHIC',
    'COLOR EVOLUTION' => 'COLOR EVOLUTION',
    'HOT STAMP' => 'HOT STAMP',
    'Laser Engraving' => 'Laser Engrave',
    'DIGITAL' => 'DIGITAL'
  }

  def initialize
    @src_file = File.join(JOBS_DATA_ROOT, '2012AABCATALOG.xlsx')
    super 'American Ad Bag'
  end


  def parse_products
    wksheets = RubyXL::Parser.parse(@src_file)
    ws = wksheets[0]
    @dup_product = Array.new
    ws.rows.each_with_index do |row,index|
      
      @dup_product.include?(row["PRODUCT NAME"]) ? next : @dup_product << row["PRODUCT NAME"] 
      ProductDesc.apply(self) do |pd|
        pd.supplier_num = row["ITEMNO"]
        pd.name = row["PRODUCT NAME"]
        pd.description = row["DESCRIPTION 1"]+ " " + row["DESCRIPTION 2"]
        pd.supplier_categories = [[row["CATEGORY"]]]
        pd.properties['dimension'] = parse_dimension(row["PRODUCT DIMENSIONS"])
        pd.package.weight =  Float(row["PACK WEIGHT"].gsub!("LBS",""))
        pd.package.units =  row["PACK SIZE"].to_i
        pd.package.height =  row["PACK HEIGHT"].to_f 
        pd.package.length = row["PACK LENGTH"].to_i
        pd.package.width = row["PACK WIDTH"].to_i
        
        /^(?<min>\d)\s*(-\s*(?<max>\d)\s*)? WORKING DAYS$/ =~ row["LEAD TIME"].to_s
        pd.lead_time.normal_min = min
        pd.lead_time.normal_max = max || min

        
      
        imprints = []
        c = row["COLOR"]
        colors = c.scan(c)
        imprints << [row["PRINT METHOD"],row["PRINT LOCATION"],row["PRINT SIZE"]]
        

        begin
         index+=1
         next_row = ws.next_row(index)
         break unless next_row
         colors << next_row["COLOR"] unless colors.include?(next_row["COLOR"])
         imprints << [next_row["PRINT METHOD"],next_row["PRINT LOCATION"],next_row["PRINT SIZE"]] unless imprints.include?([next_row["PRINT METHOD"],next_row["PRINT LOCATION"],next_row["PRINT SIZE"]])
        end while next_row["ITEMNO"] == row["ITEMNO"]  

        # decorations
        pd.decorations = [DecorationDesc.none]

        imprints.each do |method,location,size|
          if technique = @@decoration_replace[method]
           pd.decorations << DecorationDesc.new({:technique => technique,:location => location}.merge(parse_dimension(size)))
          else
            warning 'Unknown Decoration', method
          end  
        end

       

        #variants

        if colors.empty?
            pd.variants = [VariantDesc.new(:supplier_num => pd.supplier_num, :properties => {}, :images => [])]
        else
            colors.each do |color|
               pd.variants << VariantDesc.new(:supplier_num => pd.supplier_num + color.to_s,:properties => { 'color' => color },:images => [] )
                                                #ImageNodeFetch.new("main", "http://www.adbag.com/Images/Products/#{color}.jpg")
            end
        end


        # princing
        pricing = []
        pricing_check = false
        (1..6).each do |n|
            pricing << [row["QTY BREAK #{n}"],row["SELL/COST #{n}"]]
        end

        
        pricing.each do |qty,cost|
          /^(?<qty_min>\d*)\s*-\s*(?<qty_max>\d*)$/ =~ qty.to_s
          qty_1,qty_2 = cost.split("/") 
          next unless qty_2.to_f != 0.0 && qty_min.to_i != 0
          pd.pricing.add(qty_min.to_i, qty_1.to_f, qty_2.to_f) 
          pricing_check = true
        end 

        
        if pricing_check
         # pd.pricing.apply_code(row["PRICE CODES"], :reverse => true, :fill => true)
          pd.pricing.ltm(32.0)
          pd.pricing.maxqty
        end
        
        pd.tags = []

      end
    end  
  end
end
