class MagnetGroupXLS < GenericImport
  def initialize
    super 'The Magnet Group'
  end

  def fetch_parse?
    return false unless super

    puts "Starting Fetch"
    agent = Mechanize.new
    page = agent.get('http://transfer.themagnetgroup.com/TMG/HTCOMNET/')
    page.form_with(:action => 'Default.aspx') do |f|
      f['txtUsername'] = 'distributor'
      f['txtPassword'] = 'data'
    end.click_button

    page = agent.get('http://transfer.themagnetgroup.com/TMG/HTCOMNET/List.aspx')
    
    files = page.body.scan(/fil\(\d+,'.+?','.+?',\d+,\s'(.+?)',.+?\)/).flatten

    xlss = files.collect { |f| /^Product Pricing Extract - (\d{2})(\d{2})(\d{2})\.xls$/ === f ? [f, Date.new(('20'+$3).to_i, $1.to_i, $2.to_i)] : nil }.compact
    xls = xlss.sort_by { |f, d| d }.last.first

    @src_file = File.join(JOBS_DATA_ROOT, xls)
    if File.exists?(@src_file)
      puts "File already downloaded: #{@src_file}"
      return false
    else
      puts "Starting Download"
      page = agent.get("http://transfer.themagnetgroup.com/TMG/HTCOMNET/getfile.aspx?file=#{xls}")
      page.save_as @src_file
      puts "Downloaded: #{@src_file}"
      return true
    end
  end

  def parse_products
    #fetch
    @src_file = File.join(JOBS_DATA_ROOT, 'Product Pricing Extract - 092512.xls') unless @src_file

    unique_columns = %w(setupChargeDescription NetSetupCharge PrintMethod PriceMethod priceIncludesBrandNote priceIncludesItemNote priceIncludesCategoryNote AsLowAsCatalog AsLowAsNet) +
      %w(qty catalog net code AddColorPrice AddColorDiscountCode).map { |s| (1..10).map { |i| "#{s}#{i}" } }.flatten


    ws = Spreadsheet.open(@src_file).worksheet(0)
    all_columns = ws.use_header.keys
    raise "Unknown header: #{(unique_columns - all_columns).inspect}" unless (unique_columns - all_columns).empty?
    product_merge = ProductRecordMerge.new(unique_columns, all_columns - unique_columns)
    ws.each(1) do |row|
      begin
        product_merge.merge(row['itemNumber'].strip, row)
      rescue Exception => e
        puts "RESCUE: #{e}"
      end
    end
    
    product_merge.each do |supplier_num, unique, common|
      next if %w(IC265 PUTAGBK).include?(supplier_num)
      ProductDesc.apply(self) do |pd|
        pd.supplier_num = supplier_num
        pd.name = common['ItemName'].strip
        pd.description = common['description'] && common['description'].split(/\s*[.;][.; ]+/).collect do |s|
          next if s.include?('Purchase order')
          next if s.include?('See 24')
          /[.?!]\s*/ === s ? s : "#{s}."
        end.compact
        pd.supplier_categories = [[common['brandName'].strip, common['ProductCategoryName'].strip]]
        pd.images = []

        pd.properties = {
          'dimension' => { 
            'width' => 'w',
            'height' => 'h',
            'depth' => 'l' }.each_with_object({}) do |(col, key), size|
            size[key] = Float(common[col]) unless Float(common[col]) == 0.0
          end,
          'material' => common['PrimaryMaterial']
        }

        # Tags
        pd.tags = {
          'newProduct' => 'New',
          'priceBuster' => 'Special',
          'thinkGreen' => 'Eco',
          'closeout' => 'Closeout' }.collect do |col, tag|
          common[col] == 'YES' ? tag : nil
        end.compact

        # Shipping
        unless common['ShipQty1'].blank?
          pd.package.merge_from_object(common, { 'units' => 'ShipQty1',
                                         'weight' => 'ShipWeightinLBs'})
        end

        unless common['ShipLength1'].blank? || common['ShipLength1'] == 'Custom Box'
          mapping = %w(length width height).each_with_object({}) do |dim, hash|
            hash[dim] = "Ship#{dim.capitalize}1"
          end
          pd.package.merge_from_object(common, mapping)
        end

        # Leed Time
        if /^(\d{1,2})-(\d{1,2}) working days$/ === common['standardProductionTime']
          pd.lead_time.normal_min = Integer($1)
          pd.lead_time.normal_max = Integer($2)
          pd.lead_time.rush = 1 if common['quickShip'] == 'YES'
        else
          puts "Unkown Production Time: #{common['standardProductionTime'].inspect}"
        end

        # Setup initial variant with colors
        if common['itemHasVariations'] == 'YES' and common['Item_Variations']
          variants = common['Item_Variations'].split(/\s*,\s*/)
            .zip(common['AvailableColors'].split(/\s*,\s*/)).collect do |num, color|
            VariantDesc.new(:supplier_num => num, :properties => { 'color' => color })
          end
        else
          variants = [VariantDesc.new(:supplier_num => supplier_num, :properties => {})]
        end

        # Add images to variants
        variants = variants.each do |variant|
          variant.images =
            [ImageNodeFetch.new("#{variant.supplier_num}HR.jpg",
                                "http://www.themagnetgroup.com/images/product/HR/#{variant.supplier_num}HR.jpg")]
        end

        unique.each do |uniq|
          pricing = PricingDesc.new
          (1..10).each do |i|
            next if (qty = uniq["qty#{i}"]).blank?
            pricing.add(qty, uniq["catalog#{i}"], uniq["net#{i}"])
          end
          pricing.maxqty
          pricing.ltm_if(40.0, common['MinimumQuantity'])
          
          uniq[:pricing] = pricing
        end

        imprint_dim = common['imprintHeight'].blank? ? {} : {
          :width => Float(common['imprintHeight']),
          :height => Float(common['imprintWidth']) }

        cnt = unique.count { |u| u['PriceMethod'] && u['PriceMethod'].include?('Thickness') }
        if cnt == unique.length
          # All Variants with Thickness
          pd.variants = unique.collect do |uniq|
            raise "Unknown Tickness: #{uniq['PriceMethod'].inspect}" unless /^((?:\.\d{3})|(?:\d{2}[GPR])) Thickness$/ === uniq['PriceMethod']
            
            variants.collect do |variant|
              variant = variant.dup
              variant.pricing = uniq[:pricing]
              puts "Thick: #{$1}"
              variant.supplier_num += "-#{$1}"
              variant.properties.merge!('thickness' => $1)
              variant
            end
          end.flatten
          
          pd.decorations = [DecorationDesc.new({:technique => '4 Color Photographic',
                                                 :location => '' }.merge(imprint_dim))]
        else
          puts "Mismatch #{supplier_num} #{unique.inspect}" unless cnt == 0
          unique.each do |elem|
            puts "  #{elem['PrintMethod']} #{elem['PriceMethod']}"
          end
          uniq = unique.sort_by { |uniq| uniq[:pricing].prices.first[:marginal] }.last
          pd.variants = variants.collect do |variant|
            raise "Price" unless uniq[:pricing]
            variant.pricing = uniq[:pricing]
            variant
          end
          
          pd.decorations = [DecorationDesc.none]
        end
      end
    end
  end
end
