# ToDO
# Quantity on decoration pricing

class CrownProdXLS < GenericImport
  def initialize
    @src_file = File.join(JOBS_DATA_ROOT, 'CrownProductData.xls')
    super 'Crown Products'
  end

  def imprint_colors
    %w(032 Reflex\ Blue Black White 021 161 872 877)
  end

  def fetch_parse?
    if File.exists?(@src_file) and
        File.mtime(@src_file) >= (Time.now - 14.day)
      puts "File Fetched today"
      return false
    end
    
    puts "Starting Fetch"
    
    agent = Mechanize.new
    page = agent.get('http://crownprod.com/includes/productdata.php')
    form = page.forms.first
    form.action = '/' + form.action
    page = agent.submit(form)
    
    page.save! @src_file
    
    puts "Fetched"
    true
  end

  @@decoration_map = {
    'laser engraved' => 'Laser Engrave',
    'silk screen' => 'Screen Print',
    'silk screened' => 'Screen Print',
    'debossed' => 'Deboss',
  }
  cattr_reader :decoration_map


  def parse_products
    ss = Spreadsheet.open(@src_file)
    ws = ss.worksheet(1)
    ws.use_header
    setups = {}
    setups.default = []
    running = {}
    ws.each(1) do |row|
      supplier_num = row['Item# (SKU)']
      case row['Charge Type']
      when 'SETUP'
        hash = { :fixed => Float(row['Setup']) }
        case row['Charge Name']
        when /deboss/i
          hash.merge!(:technique => 'Deboss')
        when /laser/i
          hash.merge!(:technique => 'Laser Engrave')
        when /screen/i
          hash.merge!(:technique => 'Screen Print')
        end
        setups[supplier_num] += [hash]

      when 'RUN'
        list = []
        (1..5).each do |i|
          r = Float(row["Run Charge-Qty#{i}"])
          break if r == 0;
          list << r
        end
        #        hash = { :pricing => list }
        hash = { :marginal => list.first }
        running[supplier_num] = (running[supplier_num] || {}).merge(hash)
      else
        raise "Unkown Charge Type: #{row['Charge Type']}"
      end
    end

    # Remove duplicate setups and choose highest price
    setups.each do |sup_num, list|
      @supplier_num = sup_num
      list = list.uniq.group_by { |h| h[:technique] }.collect do |tech, hashs|
        next unless hashs.length > 1
        warning "Duplicate Setups", hashs.inspect
        hashs.sort_by { |h| h[:fixed] }.last
      end.compact
      setups[sup_num] = list unless list.empty?
    end


    ws = ss.worksheet(2)
    ws.use_header
    sales = {}
    # Sale column no longer around.  Probably bug on Crowns side
#    ws.each(1) do |row|
#      next unless row['Sale?'] == 'Y'
#      next unless Float(row['Sale Qty']) > 0.0
#      pricing = PricingDesc.new
#      pricing.add(row['Sale Qty'], row['Sale Price'], row['Sale Code'])
#      sup_num = row['Item# (SKU)'].to_s.strip
#      sales[sup_num] = pricing
#    end

    variations = {}
    variations['info_list'] = {}
    variations['info_list'].default = []

    ws = ss.worksheet(0)
    ws.use_header


    puts "Start Image Find"
    file_name = cache_file("#{@supplier_name}_images")
    image_hash = cache_exists(file_name) ? cache_read(file_name) : {}
    begin
      Net::HTTP.start('ecommerce.crownprod.com') do |http|
        ws.each(1) do |row|
          supplier_num = row['Item# (SKU)']
          image_id = supplier_num.gsub(/_(CL|OS)$/, '')
          next if image_hash[image_id] #and !image_hash[image_id].empty?
          image_list = []

          doc = nil
          begin
            doc = WebFetch.new("http://www.crownprod.com/includes/productimages.php?browse=HIGHRES&itemno=#{image_id}").get_doc
          rescue
            warning "Image Fetch Fail"
          end
          if doc
            doc.search('a').each do |a|
              href = a.attributes['href'].value
              uri = URI.parse(href)
              raise "Unknown host" if uri.host != 'ecommerce.crownprod.com'
              head = http.head(uri.request_uri)
              unless /^attachment; filename=(.+\.jpg)$/ === head['content-disposition']
                raise "Unknown disposition: #{href} : #{head['content-disposition']}"
              end
              filename = $1
              unless /^(?:(.+?)%5C)?(.+?(?:[+_](.+?))?)\.jpg$/ === filename
                raise "Unknown file: #{filename}"
              end
              desc = $3 || $2
              
              unless (match = image_list.find_all { |n| n.first.id == filename }).empty?
                unless /^(.+?)(?:_(\d))?\.jpg$/ === match.last.first.id
                  raise "Unknown filesub: #{filename}"
                end
                filename = "#{$1}_#{($2 && ($2.to_i+1)) || 1}.jpg"
              end
              puts "  HEAD: #{uri.request_uri} => #{filename}"

              image_list << [ImageNodeFetch.new(filename, href, ($1 == 'Blanks') ? 'blank' : nil), desc.gsub(/\+|_/,' ').strip]
            end
            image_hash[image_id] = image_list
            next unless image_list.empty?
          end
          
          if doc = WebFetch.new("http://www.crownprod.com/?p=viewitem&itemno=#{supplier_num}").get_doc
            image_list = doc.search('div[@id="img_slide"]/img').collect do |n|
              url = n.attributes['src'].value
              unless /^image\.php\?sz=th&id=(\d+)$/ === url
                raise "Unknown URL: #{url}"
              end
              id = $1
              puts "  ID: #{id}"
              [ImageNodeFetch.new(id, "http://www.crownprod.com/image.php?sz=xl&id=#{id}"), '']
            end
          end

          image_hash[image_id] = image_list
        end
      end
    ensure
      cache_write(file_name, image_hash)
    end

    ws.each(1) do |row|
      next unless @supplier_num = row['Item# (SKU)']

      puts
      puts "Product: #{@supplier_num}"

      %w(Price\ Includes).each do |name|
        variations[name] ||= {}
        value = row[name]
        variations[name][value] = (variations[name][value] || []) + [@supplier_num]
      end

      ProductDesc.apply(self) do |pd|
        pd.supplier_num = @supplier_num
        pd.name = row['Item Name']
        pd.description = (row['Product Description'] || '').gsub(".", ".\n").strip
        if row['Product Categories']
          pd.supplier_categories = row['Product Categories'].split(',').collect { |s| [s.strip] }
        else
          pd.supplier_categories = [['unknown']]
        end
        pd.package.weight = row['Shipping Weight (lbs)'] && Float(row['Shipping Weight (lbs)'])
        pd.package.units = row['Shipping Quantity'] && row['Shipping Quantity'].to_i

        pd.tags << 'Closeout' if @supplier_num.include?('_CL')

        info_list = (row['Additional Info'] || '')
          .scan(/\s*(?:(?:\d\.\s*(.+?(?:[.?!]|$)))|(.+?(?:[.?!]|$)))\s*/).collect { |a, b| s = (a || b).strip; s.blank? ? nil : s }
          .compact.collect { |s| s.gsub(/\s*\d\.$/,'') }
        info_list.each do |str|
          variations['info_list'][str] += [@supplier_num]
        end
        if info_list.find { |i| i.length <= 2 }
          puts "INFO: #{row['Additional Info'].inspect} : #{info_list.inspect}"
        end


        if sales[@supplier_num]
          pd.pricing = sales[@supplier_num]
          pd.tags << 'Special'
          e = (1..5).collect { |i| row["Pricing-Qty#{i}"] && Integer(row["Pricing-Qty#{i}"]) }.compact.max
          pricing.maxqty(e && e*2)
        else
          (1..5).each do |i|
            break if (qty = row["Pricing-Qty#{i}"]).blank?
            pd.pricing.add(qty, row["Pricing-Price#{i}"], row["Pricing-Code#{i}"])
          end
          pd.pricing.maxqty
        end
        info_list.delete(e) if e = info_list.find { |e| /Less than.+not avalable/i === e }
        pd.pricing.ltm(40.0, 1) unless e

        info_list.delete_if do |s|
          next true if s.include?('on PO')
          not (/^[A-Z].{5}.+?\.$/ === s)
        end
        pd.description += info_list.collect { |s| "\n" + s }.join


        puts "Area: #{row['Imprint Area']}"
        locations = parse_areas(row['Imprint Area'])
        locations.delete_if { |loc| [:height, :width].find { |a| loc[a].nil? } }
        locations.each do |imprint|
          puts "  #{imprint.inspect}"
        end

        includes = []
        row['Price Includes'].split(',').each do |str|
          location = nil
          if /^(.+?)\s+on\s+(.+?)\.?$/ === str
            str = $1
            location = $2
          end

          hash = case str
                 when /(\d)-(\d) color/i
                   { :technique => 'Pad Print', :limit => Integer($2) }
                 when /digital\s+color/i, /4\s+|-color\s+process/i
                   { :technique => 'Photo Transfer' }
                 when /dome/i
                   { :technique => 'Dome' }
                 when /laser/i
                   { :technique => 'Laser Engrave' }
                 when /embroider/i
                   { :technique => 'Embroidery' }
                 when /deboss/i
                   { :technique => 'Deboss' }
                 when /onc?e\s+color/i
                   { :limit => 1 }
                 when /\d side/i
                   {}
                 else
                   warning 'Unkown Price Includes', "#{row['Price Includes']} => #{str}"
                   {}
                 end
          includes << hash.merge(:location => location || '')
        end if row['Price Includes']

        puts "Includes: #{row['Price Includes']}"
        includes.each do |imprint|
          puts "  #{imprint.inspect}"
        end

        puts "Setups:"
        setups[@supplier_num].each do |imprint|
          puts "  #{imprint.inspect}"
        end

        puts "Running: #{running[@supplier_num].inspect}"

        combos = [locations, includes, setups[@supplier_num], [running[@supplier_num]]]
        puts "PARTS: #{combos.inspect}"
#        pd.decorations = [DecorationDesc.none]
        pd.decorations = decorations_from_parts(combos, [], :minimal => true)

        
        
        colors = row['Available Colors'] ? row['Available Colors'].split(/\s*,\s*/).collect { |c| c.split(' ').collect { |w| w.capitalize }.join(' ') }.uniq : ['']
        

        images = image_hash[@supplier_num.gsub(/_(CL|OS)$/, '')]
        
        if images.nil? or images.empty?
          puts " Using default image: #{@supplier_num}"
          color_image_map = {}
          pd.images = [ImageNodeFetch.new('default',
                                          "http://www.crownprod.com/image.php?sz=xl&itemno=#{@supplier_num}")]
        else
          color_image_map, color_num_map = match_image_colors(images, colors, :prune_colors => true)
          pd.images = color_image_map[nil] || []
        end
        
        pd.variants = colors.collect do |color|
          VariantDesc.new(:supplier_num => "#{@supplier_num}-#{color}",
                          :properties => { 'color' => color },
                          :images => color_image_map[color] || [])
        end
      end
    end

    variations.each do |name, hash|
      puts "#{name}:"
      hash.to_a.sort_by { |k, v| k || '' }.each do |elem, list|
        puts "  #{list.length}: #{elem.inspect}" # : #{list.join(',')}"
      end
    end
  end
end
