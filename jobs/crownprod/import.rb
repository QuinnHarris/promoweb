# ToDO
# Quantity on decoration pricing

class CrownProdXLS < GenericImport
  def initialize
    @src_file = File.join(JOBS_DATA_ROOT, 'CrownProductData.xls')
    super 'Crown Products'
  end

  def fetch_parse?
    if File.exists?(@src_file) and
        File.mtime(@src_file) >= (Time.now - 1.day)
      puts "File Fetched today"
      return false
    end
    
    puts "Starting Fetch"
    
    agent = Mechanize.new
    page = agent.get('http://crownprod.com/includes/productdata.php')
    form = page.forms.first
    form.action = '/' + form.action
    page = agent.submit(form)
    
    page.save_as @src_file
    
    puts "Fetched"
    true
  end

  @@decoration_map = {
    'Laser Engraved' => 'Laser Engrave',
    'Silk Screen' => 'Screen Print',
    'Silk Screened' => 'Screen Print',
    'Debossed' => 'Deboss',
  }
  cattr_reader :decoration_map


  def parse_products
    ss = Spreadsheet.open(@src_file)
    ws = ss.worksheet(1)
    ws.use_header
    decorations = {}
    ws.each(1) do |row|
      supplier_num = row['Item# (SKU)']
      case row['Charge Type']
        when 'SETUP'
        hash = { :fixed => Float(row['Setup']) }
        when 'RUN'
        list = []
        (1..5).each do |i|
          r = Float(row["Run Charge-Qty#{i}"])
          break if r == 0;
          list << r
        end
#        hash = { :pricing => list }
        hash = { :marginal => list.first }
        else
        raise "Unkown Charge Type: #{row['Charge Type']}"
      end
      decorations[supplier_num] = (decorations[supplier_num] || {}).merge(hash)
    end

    puts "Decoration Pricing:"
    decorations.values.uniq.each do |dec|
      count = decorations.values.find_all { |v| v == dec }.length
      puts "  #{count}: #{dec.inspect}"
    end

    ws = ss.worksheet(2)
    ws.use_header
    sales = {}
    ws.each(1) do |row|
      next unless row['Sale?'] == 'Y'
      pricing = PricingDesc.new
      pricing.add(row['Sale Qty'], row['Sale Price'], row['Sale Code'])
    end

    variations = {}
    variations['info_list'] = {}
    variations['info_list'].default = []

    ws = ss.worksheet(0)
    ws.use_header
    ws.each(1) do |row|
      next unless @supplier_num = row['Item# (SKU)']

      %w(Price\ Includes).each do |name|
        variations[name] ||= {}
        value = row[name]
        variations[name][value] = (variations[name][value] || []) + [@supplier_num]
      end

      ProductDesc.apply(self) do |pd|
        pd.supplier_num = @supplier_num
        pd.name = row['Item Name']
        pd.description = (row['Product Description'] || '').gsub(".", ".\n").strip
        pd.supplier_categories = [[row['Product Categories'].strip]]
        pd.package.weight = row['Shipping Weight'] && Float(row['Shipping Weight'])
        pd.package.units = row['Shipping Quantity'] && row['Shipping Quantity'].to_i
        pd.tags = []

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


        if pricing = sales[@supplier_num]
          tags << 'Special'
          e = (1..5).collect { |i| Integer(row["Pricing-Qty#{i}"]) }.max
          pricing.maxqty(e*2)
        else
          pricing = PricingDesc.new
          (1..5).each do |i|
            break if (qty = row["Pricing-Qty#{i}"]).blank?
            pricing.add(qty, row["Pricing-Price#{i}"], row["Pricing-Code#{i}"])
          end
          pricing.maxqty
        end
        info_list.delete(e) if e = info_list.find { |e| /Less than.+not avalable/i === e }
        pricing.ltm(40.0, 1) unless e

        info_list.delete_if do |s|
          next true if s.include?('on PO')
          not (/^[A-Z].{5}.+?\.$/ === s)
        end
        pd.description += info_list.collect { |s| "\n" + s }.join


        puts "Area: #{row['Imprint Area']}"
        locations = parse_areas(row['Imprint Area'], @supplier_num)
        locations.each do |imprint|
          puts "  #{imprint.inspect}"
        end

        pd.decorations = [DecorationDesc.none]



        
        
        colors = row['Available Colors'] ? row['Available Colors'].split(/\s*,\s*/).collect { |c| c.split(' ').collect { |w| w.capitalize }.join(' ') } : ['']
        
        image_list_path = WebFetch.new("http://www.crownprod.com/includes/productimages.php?browse&itemno=#{@supplier_num.gsub(/_CL$/, '')}").get_path
        doc = Nokogiri::HTML(open(image_list_path))
        images = doc.xpath("//td[@class='hires_download_file']/a").collect do |a|
          href = a.attributes['href'].value
          
          unless /file=((?:(.+?)%5C)?(.+?(?:[+_](.+?))?)\.jpg)$/i === href
            raise "Unknown href: #{href}"
          end
          desc = $4 || $3
          
          [ImageNodeFetch.new($1, href, ($2 == 'Blanks') ? 'blank' : nil), desc.gsub(/\+|_/,' ').strip]
        end
        
        if images.empty?
          puts " Using default image: #{@supplier_num}"
          color_image_map = {}
          pd.images = [ImageNodeFetch.new('default',
                                          "http://www.crownprod.com/images/items/BRIGTEYE_CL_xl.jpg")]
        else
          color_image_map, color_num_map = match_image_colors(images, colors, @supplier_num)
          pd.images = color_image_map[nil]
        end
        
        pd.variants = colors.collect do |color|
          VariantDesc.new(:supplier_num => "#{@supplier_num}-#{color}",
                          :properties => { 'color' => color },
                          :images => color_image_map[color] || [],
                          :pricing => pricing)
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
