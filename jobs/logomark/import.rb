class LogomarkXLS < GenericImport
  def initialize
    time = Time.now - 1.day
    #%w(Data Data_Portfolio CloseoutsData ECOData)
    @src_urls = %w(Data).collect do |name|
      "http://www.logomark.com/Media/DistributorResources/Logomark#{name}.xls"
    end
    
    super 'Logomark'
  end

  def fetch_parse?
    time = Time.now - 1.day
    fetched = false
    @src_files = @src_urls.collect do |url|
      wf = WebFetch.new(url)
      fetched = true if wf.fetch?(time)
      wf.get_path(time)
    end
    fetched
  end

  def set_decoration(line, type, aspect, value, warn = false)
    @decorations[line] ||= {}
    @decorations[line][type] ||= {}    

    if (prev = @decorations[line][type][aspect]) and
        (prev != value)
      raise "Tried to overwrite #{line} #{type} #{aspect} #{prev.inspect} != #{value.inspect}" unless warn
    end

    @decorations[line][type][aspect] = value
    puts "Set: #{line} #{@decorations[line].inspect}"
  end

  def parse_products
    unique_columns = %w(SKU Item\ Color)
    common_columns = %w(Product\ Line Name Description Features Finish\ /\ Material IsAdvantage24 Categories Item\ Size Decoration\ Height Decoration\ Width LessThanMin1Qty LessThanMin1Charge End\ Column\ Price Box\ Weight Quantity\ Per\ Box Box\ Length Production\ Time) + (1..6).collect { |i| %w(Qty Price Code).collect { |s| "PricePoint#{i}#{s}" } }.flatten

    @src_files.each do |file|
      puts "Processing: #{file}"
      ss = Spreadsheet.open(file)

      # Decoration Charges
      puts "Processing Decorations"
      @decorations = {}
      ltm = {}
      ws = ss.worksheet(2)
      ws.use_header
      ws.each(1) do |row|
        next unless row['Product Line']
        line = row['Product Line'].strip
        case row['ChargeName']
        when 'Less Than Minimum'
          if /absolute minimum : (\d{2,3})/i === row['Description']
            ltm[line] = Integer($1)
          else
            ltm[line] = Integer(row['Charge'])
          end
        when 'Setup'
          name = row['Imprint Name']
          if name.blank?
            next unless /^(.*?)(?:\s+|^)(?:per|each)/ === row['Description']
            name = $1
          end
          set_decoration(line, row['Imprint Name'], :fixed, Float(row['Charge']))
        when 'Second Location'
          raise "Unknown Desc: #{row['Description']}" unless /^(.*?)(?:\s+|^)(?:per|each)/ === row['Description']
          set_decoration(line, $1, :marginal, Float(row['Charge']), true)
        when 'Additional Run Charge'
          unless /^(.*?)(?:\s+|^)(?:per|each)/ === row['Description']
            unless /^second (?:color|location) (\w+)/i === row['Description']
              raise "Unknown Desc: #{row['Description']}" 
            end
          end
          set_decoration(line, $1.capitalize, :marginal, Float(row['Charge']))
        when 'Repeat Setup'
        when 'Art'
        when 'Pre-Production Proof'
        when 'Oxidation'
        when 'Personalization'
        when 'Custom Foam Die Charge'
        when 'Color Fill'
        else
          raise "Unkonwn Charge: #{row['ChargeName']}"
        end
      end

      puts "Decorations: "
      @decorations.each do |line, hash|
        puts "  #{line}: #{hash.inspect}"
      end
      

      # ProductModelXRef
      puts "Processing XRefs"
      model_product = {}
      ws = ss.worksheet(3)
      ws.use_header
      ws.each(1) do |row|
        model_product[row['ModelSKU']] = row['ProductSKU']
      end


      # Flat Data
      puts "Processing Main List"
      product_merge = ProductRecordMerge.new(unique_columns, common_columns)
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

        ProductDesc.apply(self) do |pd|
          pd.supplier_num = supplier_num
          pd.name = "#{common['Name'] || supplier_num} #{common['Description']}"
          pd.description = common['Features'] || ''
          pd.supplier_categories = (common['Categories'] || '').split(',').collect { |c| [c.strip] }

          pd.package.units = common['Quantity Per Box']
          pd.package.weight = common['Box Weight']

          unless /^(\d+)-(\d+) Working ((?:Days)|(?:Weeks))$/ === common['Production Time']
            raise "Unkown Production Time: #{supplier_num} #{common['Production Time']}"
          end
          multiplier = ($3 == 'Days') ? 1 : 5
          pd.lead_time.normal_min = Integer($1) * multiplier
          pd.lead_time.normal_max = Integer($2) * multiplier
          pd.lead_time.rush = 1 if common['IsAdvantage24'] == 'YES'

          pd.properties = {
            'material' => common['Finish / Material'],
            'size' => common['Item Size'] && parse_volume(common['Item Size'])
          }


          pricing = PricingDesc.new
          (1..6).each do |i|
            qty = common["PricePoint#{i}Qty"]
            next if qty.blank? or Integer(qty) < 1
            pricing.add(qty, common["PricePoint#{i}Price"], common["PricePoint#{i}Code"])
          end
          pricing.maxqty
          unless common['LessThanMin1Qty'] == 0
            pricing.ltm_if(common['LessThanMin1Charge'], common['LessThanMin1Qty'])
          end
        
          pd.decorations = [DecorationDesc.none]


          pd.images = [ImageNodeFetch.new("Group/#{supplier_num}.jpg",
                                          "http://www.logomark.com/Image/Group/Group800/#{supplier_num}.jpg")]
          
          pd.variants = unique.collect do |uniq|
            VariantDesc.new(:supplier_num => uniq['SKU'],
                            :images => uniq['images'] || [], :pricing => pricing,
                            :properties => { 'color' => uniq['Item Color'].strip } )
          end
        end
      end
    end
  end
end
