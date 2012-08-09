class MagnetGroupXLS < GenericImport
  def initialize
    super 'The Magnet Group'
  end

  def fetch
    puts "Starting Fetch"
    agent = Mechanize.new
    page = agent.get('http://transfer.themagnetgroup.com/TMG/HTCOMNET/')
    page.form_with(:action => 'Default.aspx') do |f|
      f['txtUsername'] = 'distributor'
      f['txtPassword'] = 'data'
    end.click_button

    page = agent.get('http://transfer.themagnetgroup.com/TMG/HTCOMNET/List.aspx')
    
    files = page.body.scan(/fil\(\d+,'.+?','.+?',\d+,\s'(.+?)',.+?\)/).flatten

    xlss = files.find_all { |f| /^Product Pricing Extract - \d{6}\.xls$/ === f }
    if xlss.length == 1
      xls = xlss.first
    else
      raise "Wrong # of Files: #{xls.inspect} from #{files.inspect}"
    end

    @src_file = File.join(JOBS_DATA_ROOT, xls)
    if File.exists?(@src_file)
      puts "File already downloaded: #{@src_file}"
    else
      puts "Starting Download"
      page = agent.get("http://transfer.themagnetgroup.com/TMG/HTCOMNET/getfile.aspx?file=#{xls}")
      page.save_as @src_file
      puts "Downloaded: #{@src_file}"
    end
  end

  def parse_products
    #fetch
    @src_file = File.join(JOBS_DATA_ROOT, 'Product Pricing Extract - 073112.xls')

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
      puts supplier_num
      product_data = {
        'supplier_num' => supplier_num,
        'name' => common['ItemName'].strip,
        'description' => common['description'] ? common['description'].gsub(/\.\s+/,".\n") : '',
        'supplier_categories' => [[common['brandName'].strip, common['ProductCategoryName'].strip]],
        'images' => []
      }

      common_properties = {
        'size' => { 
          'width' => 'w',
          'height' => 'h',
          'depth' => 'l' }.each_with_object({}) do |(col, key), size|
            size[key] = Float(common[col]) unless Float(common[col]) == 0.0
        end,
        'material' => common['PrimaryMaterial']
      }

      # Tags
      product_data['tags'] = {
        'newProduct' => 'New',
        'priceBuster' => 'Special',
        'thinkGreen' => 'Eco',
        'closeout' => 'Closeout' }.collect do |col, tag|
        common[col] == 'YES' ? tag : nil
      end.compact

      # Shipping
      unless common['ShipQty1'].blank?
        product_data.merge!('package_units' => Integer(common['ShipQty1']),
                            'package_weight' => Float(common['ShipWeightinLBs']))
      end

      unless common['ShipLength1'].blank? || common['ShipLength1'] == 'Custom Box'
        %w(length width height).each do |dim|
          product_data["pacakge_#{dim}"] = Float(common["Ship#{dim.capitalize}1"])
        end
      end

      # Leed Time
      if /^(\d{1,2})-(\d{1,2}) working days$/ === common['standardProductionTime']
        product_data.merge!('lead_time_normal_min' => Integer($1),
                            'lead_time_normal_max' => Integer($2))
        product_data['lead_time_rush'] = 1 if common['quickShip'] == 'YES'
      else
        puts "Unkown Production Time: #{common['standardProductionTime'].inspect}"
      end



      # Setup initial variant with colors
      if common['itemHasVariations'] == 'YES' and common['Item_Variations']
        variants = common['Item_Variations'].split(/\s*,\s*/)
          .zip(common['AvailableColors'].split(/\s*,\s*/)).collect do |num, color|
          { 'supplier_num' => num, 'properties' => { 'color' => color } }
        end
      else
        variants = [{ 'supplier_num' => supplier_num, 'properties' => {} }]
      end

      # Add images to variants
      variants = variants.each do |variant|
        variant_num = variant['supplier_num']
        variant['images'] =
          [ImageNodeFetch.new("#{variant_num}HR.jpg",
                              "http://www.themagnetgroup.com/images/product/HR/#{variant_num}HR.jpg")]
      end

      unique.each do |uniq|
        uniq[:pricing] = SupplierPricing.get do |pricing|
          (1..10).each do |i|
            next if (qty = uniq["qty#{i}"]).blank?
            pricing.add(qty, uniq["catalog#{i}"], uniq["net#{i}"])
          end
        end
      end

      imprint_dim = common['imprintHeight'].blank? ? {} : {
        'width' => Float(common['imprintHeight']),
        'height' => Float(common['imprintWidth']) }

      cnt = unique.count { |u| u['PriceMethod'] && u['PriceMethod'].include?('Thickness') }
      if cnt == unique.length
        # All Variants with Thickness
        variants = unique.collect do |uniq|
          raise "Unknown Tickness: #{uniq['PriceMethod'].inspect}" unless /^((?:\.\d{3})|(?:\d{2}[GPR])) Thickness$/ === uniq['PriceMethod']

          variants.collect do |hash|
            hash = hash.merge(uniq[:pricing])
            puts "Thick: #{$1}"
            hash['supplier_num'] += "-#{$1}"
            hash['properties'] = hash['properties'].merge('thickness' => $1)
            hash
          end
        end.flatten

        decorations = [{
                         'technique' => '4 Color Photographic',
                         'location' => ''
                       }.merge(imprint_dim)]
      else
        puts "Mismatch #{supplier_num} #{unique.inspect}" unless cnt == 0
        unique.each do |elem|
          puts "  #{elem['PrintMethod']} #{elem['PriceMethod']}"
        end
        uniq = unique.sort_by { |uniq| uniq[:pricing]['prices'].first[:marginal] }.last
        variants.each do |hash|
          hash.merge!(uniq[:pricing])
        end

       decorations = [{
                         'technique' => 'None',
                         'location' => ''
                       }]
      end


      product_data['decorations'] = decorations

      product_data['variants'] = variants

      add_product(product_data)
    end
  end
end
