class LogomarkXLS < GenericImport
  def initialize
    time = Time.now - 1.day
    #%w(Data Data_Portfolio CloseoutsData ECOData)
    @src_urls = %w(Data).collect do |name|
      "http://www.logomark.com/Media/DistributorResources/Logomark#{name}.xls"
    end
    
    super 'Logomark'
  end

  def set_decoration(line, type, aspect, value, warn = false)
    @decorations[line] ||= {}
    @decorations[line][type] ||= {}    

    if (prev = @decorations[line][type][aspect]) and
        (prev != value)
      raise "Tried to overwrite #{line} #{type} #{aspect} #{prev.inspect} != #{value.inspect}" unless warn
    end

    @decorations[line][type][aspect] = value
#    puts "  Set: #{line} #{@decorations[line].inspect}"
  end

  @@decoration_map = {
    'Laser' => 'Laser Engrave',
    'Print' => 'Screen Print',
    'Deboss' => 'Deboss',
    'Vinyl' => 'Dome',
    'Laser & Oxidation' => 'Laser Engrave & Oxidation',
    'Crystal etch' => 'Crystal Etch',
  }

  # insert into decoration_techniques (name) values ('Laser Engrave & Oxidation');
  # insert into decoration_techniques (name) values ('Crystal Etch');
  # alter TABLE decoration_techniques ALTER COLUMN name type varchar(64);


  def parse_products
    unique_columns = %w(SKU Item\ Color)

    @src_files.each do |file|
      puts "Processing: #{file}"
      ss = Spreadsheet.open(file)

      # Decoration Charges
      puts "Processing Decorations:"
      @supplier_num = 'DEC'
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
#          puts "Setup Desc: #{row['Description']} => #{name}"
          set_decoration(line, name, :fixed, Float(row['Charge']))
        when 'Second Location'
          warning "Unknown Desc", row['Description'] unless /^(.*?)(?:\s+|^)(?:per|each)/ === row['Description']
#          puts "Sec Loc Desc: #{row['Description']}"
          set_decoration(line, $1, :marginal, Float(row['Charge']), true)
        when 'Additional Run Charge'
#          puts "Add Run Desc: #{row['Description']}"
          if /^(.*?)(?:\s+|^)(?:per|each)/ === row['Description']
            set_decoration(line, $1.capitalize, :marginal, Float(row['Charge']))
            next
          end
          if /^second (?:color|location) (.+)$/i === row['Description']
            if $1 == 'etch/laser'
              %w(Laser Crystal\ etch).each do |name|
                set_decoration(line, name, :marginal, Float(row['Charge']))
              end
            else
              set_decoration(line, $1.capitalize, :marginal, Float(row['Charge']))
            end
            next
          end
          warning "Unknown Add Run Charge Desc", row['Description']
        when 'Repeat Setup'
        when 'Art'
        when 'Pre-Production Proof'
        when 'Oxidation'
          set_decoration(line, 'Oxidation', :marginal, Float(row['Charge']))
        when 'Personalization'
        when 'Custom Foam Die Charge'
        when 'Color Fill'
        else
          warning "Unkonwn Charge", row['ChargeName']
        end
      end

      @decorations.each do |line, hash|
        next unless hash['Oxidation'] and hash['Laser']
        hash['Laser & Oxidation'] = hash['Laser'].merge(:marginal => hash['Oxidation'][:marginal] + hash['Laser'][:marginal])
        hash.delete('Oxidation')
      end
      @decorations['Watch Creations'] = { 'Print' => { :fixed => 65.00, :marginal => 0 } }

      cost_decorations = {}
      Decoration.transaction do
        @@decoration_map.each do |key, technique|
          costs = {}
          costs.default = []
          @decorations.each { |line, h| costs[h[key]] += [line] if h[key] }
          sorted = costs.to_a.sort_by { |h, l| l.length }
          if sorted.length == 1 or sorted[-1].last.length != sorted[-2].last.length
            default = sorted.pop.first.merge(:key => key)
            cost_decorations[default] = get_decoration(technique, default[:fixed], default[:marginal], :postfix => '')
          end
          sorted.each do |hash, list|
            k = hash.merge(:key => key)
            if k[:fixed] == default[:fixed] and !k[:marginal] and default[:marginal]
              cost_decorations[k] = cost_decorations[default]
            else
              cost_decorations[k] = get_decoration(technique, hash[:fixed] || 0.0, hash[:marginal], :postfix => list.join(', '))
            end
          end
        end
      end

      @decorations.each do |line, hash|
        puts "  #{line}:"
        hash.each do |key, values|
          unless @@decoration_map[key]
            puts "    #{key}: #{hash[key].inspect}"
            next
          end
          technique = cost_decorations[values.merge(:key => key)]
          puts "    #{key}: #{hash[key].inspect} => #{technique.inspect}"
          raise "unknown" unless hash[key] = technique
        end
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
      ws = ss.worksheet(0)
      columns = ws.use_header.keys
      product_merge = ProductRecordMerge.new(unique_columns, columns - unique_columns)
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

      begin
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
                  puts "  #{path} : #{valid}"
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
      ensure
        cache_write(file_name, images_valid)
      end
      puts "Stop Image Find"

      product_merge.each do |supplier_num, unique, common|
        next if %w(EK500 FLASH GR6140 VK3009 KT6500).include?(supplier_num)

        ProductDesc.apply(self) do |pd|
          pd.supplier_num = @supplier_num = supplier_num
          pd.name = "#{common['Name']} #{common['Description']}".strip
          pd.description = common['Features'] || ''
          pd.supplier_categories = (common['Categories'] || '').split(',').collect { |c| [c.strip] }
          pd.tags = [] # FIX !!!

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
            'dimension' => common['Item Size'] && parse_dimension(common['Item Size'])
          }


          (1..6).each do |i|
            qty = common["PricePoint#{i}Qty"]
            next if qty.blank? or Integer(qty) < 1
            pd.pricing.add(qty, common["PricePoint#{i}Price"], common["PricePoint#{i}Code"])
          end
          pd.pricing.maxqty
          unless common['LessThanMin1Qty'] == 0
            pd.pricing.ltm_if([PricingDesc.parse_money(common['LessThanMin1Charge']), Money.new(40.0)].max, common['LessThanMin1Qty'])
          end

          pd.decorations = [DecorationDesc.none]
          dec_params = { :height => common['Decoration Height'] && parse_number(common['Decoration Height']),
            :width => common['Decoration Width'] && parse_number(common['Decoration Width']) }
          if !(hash = @decorations[common['Product Line']])
            warning 'Unknown Decoration', common['Product Line']
          elsif common['Decoration Methods']
            pd.decorations += common['Decoration Methods'].split(',').collect { |n| n.strip }.uniq.collect do |tech|
              unless hash[tech]
                warning 'Unknown Technique', tech
                next
              end
              DecorationDesc.new(dec_params.merge(:limit => tech == 'Print' ? 3 : 1,
                                                  :location => '',
                                                  :technique => hash[tech]))
            end.compact
          end

          pd.images = [ImageNodeFetch.new("Group/#{supplier_num}.jpg",
                                          "http://www.logomark.com/Image/Group/Group800/#{supplier_num}.jpg")]
          
          pd.variants = unique.collect do |uniq|
            VariantDesc.new(:supplier_num => uniq['SKU'],
                            :images => uniq['images'] || [],
                            :properties => { 'color' => uniq['Item Color'].strip } )
          end
        end
      end
    end
  end
end
