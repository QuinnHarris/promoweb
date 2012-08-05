class LogomarkXLS < GenericImport
  def initialize
    time = Time.now - 1.day
    #%w(Data Data_Portfolio CloseoutsData ECOData)
    @src_files = %w(Data).collect do |name|
      WebFetch.new("http://www.logomark.com/Media/DistributorResources/Logomark#{name}.xls").
        get_path(time)
    end
    super 'Logomark'
  end

  def parse_products
    unique_columns = %w(SKU Item\ Color)
    common_columns = %w(Product\ Line Name Description Features Finish\ /\ Material IsAdvantage24 Categories Item\ Size Decoration\ Height Decoration\ Width LessThanMin1Qty LessThanMin1Charge End\ Column\ Price Box\ Weight Quantity\ Per\ Box Box\ Length Production\ Time) + (1..6).collect { |i| %w(Qty Price Code).collect { |s| "PricePoint#{i}#{s}" } }.flatten

    @src_files.each do |file|
      product_merge = ProductRecordMerge.new(unique_columns, common_columns)

      puts "Processing: #{file}"
      ss = Spreadsheet.open(file)

      # ProductModelXRef
      model_product = {}
      ws = ss.worksheet(3)
      ws.use_header
      ws.each(1) do |row|
        model_product[row['ModelSKU']] = row['ProductSKU']
      end


      # Flat Data
      ws = ss.worksheet(0)
      ws.use_header
      ws.each(1) do |row|
        next if row['SKU'].blank?
#        raise "Unkown SKU: #{row['SKU'].inspect}" unless /^([A-Z]+\d*)([A-Z]*(?:-[\w-]+)?)$/ === row['SKU']
        raise "Unknown SKU" unless supplier_num = model_product[row['SKU']]
        begin
          product_merge.merge(supplier_num, row)
        rescue Exception => e
          puts "RESCUE: #{e}"
        end
      end

      
      puts "Start Image Find"
      file_name = cache_file("Logomark_images")
      images_valid = cache_exists(file_name) ? cache_read(file_name) : {}

      Net::HTTP.start('www.logomark.com') do |http|
        product_merge.each do |supplier_num, unique, common|
          unique.each do |uniq|
            variant_num = uniq['SKU']
            list = ["/Image/Model/Model800/#{variant_num}.jpg"] +
              (1..8).collect { |i| "/Image/Model/Model800/#{variant_num}_a#{i}.jpg" }
            count = 0
            list.each do |path|
              if images_valid.has_key?(path)
                valid = images_valid[path]
              else
                valid = (http.head(path).content_type == 'image/jpeg')
                images_valid[path] = valid
              end

              if valid
                uniq['images'] = (uniq['images'] || []) + 
                  [ImageNodeFetch.new("Model/#{path.split('/').last}",
                                      "http://www.logomark.com#{path}")]
                count = 0
              else
                count += 1
                break if count >= 2
              end
            end
          end
        end
      end

      cache_write(file_name, images_valid)

      puts "Stop Image Find"

      product_merge.each do |supplier_num, unique, common|
        next if %w(EK500 FLASH GR6140 VK3009).include?(supplier_num)
        product_data = {
          'supplier_num' => supplier_num,
          'name' => "#{common['Name'] || supplier_num} #{common['Description']}",
          'description' => common['Features'] || '',
          'supplier_categories' => (common['Categories'] || '').split(',').collect { |c| [c.strip] },
          'package_units' => Integer(common['Quantity Per Box']),
          'package_weight' => Float(common['Box Weight'])
        }

        unless /^(\d+)-(\d+) Working ((?:Days)|(?:Weeks))$/ === common['Production Time']
          raise "Unkown Production Time: #{supplier_num} #{common['Production Time']}"
        end
        multiplier = ($3 == 'Days') ? 1 : 5
        product_data.merge!('lead_time_normal_min' => Integer($1) * multiplier,
                            'lead_time_normal_max' => Integer($2) * multiplier)
        product_data['lead_time_rush'] = 1 if common['IsAdvantage24'] == 'YES'

        common_properties = { 'material' => common['Finish / Material'],
          'size' => common['Item Size'] && parse_volume(common['Item Size'])
        }


        common_variant = SupplierPricing.get do |pricing|
          (1..6).each do |i|
            qty = common["PricePoint#{i}Qty"]
            break if qty.blank? or qty == '0'
            pricing.add(qty, common["PricePoint#{i}Price"], common["PricePoint#{i}Code"])
          end
          pricing.maxqty
          unless common['LessThanMin1Qty'] == 0
            pricing.ltm_if(common['LessThanMin1Charge'], common['LessThanMin1Qty'])
          end
        end


        decorations = [{
                         'technique' => 'None',
                         'location' => ''
                       }]
        product_data['decorations'] = decorations


        product_data['images'] = [ImageNodeFetch.new("Group/#{supplier_num}.jpg",
                                                     "http://www.logomark.com/Image/Group/Group800/#{supplier_num}.jpg")]

        product_data['variants'] = unique.collect do |uniq|
          { 'supplier_num' => variant_num = uniq['SKU'],
            'properties' => { 'color' => uniq['Item Color'] },
            'images' => uniq['images']
          }.merge(common_variant)
        end

        add_product(product_data)
      end
    end
  end
end