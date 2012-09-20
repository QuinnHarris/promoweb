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


  def parse_products
    ss = Spreadsheet.open(@src_file)
    ws = ss.worksheet(0)
    ws.use_header
    ws.each(1) do |row|
      next unless supplier_num = row['Item# (SKU)']

      ProductDesc.apply(self) do |pd|
        pd.supplier_num = supplier_num
        pd.name = row['Item Name']
        pd.description = (row['Product Description'] || '').gsub(".", ".\n").strip
        pd.supplier_categories = [[row['Product Categories'].strip]]
        pd.package.weight = row['Shipping Weight'] && Float(row['Shipping Weight'])
        pd.package.units = row['Shipping Quantity'] && row['Shipping Quantity'].to_i
        pd.tags = []

        pd.tags << 'Closeout' if supplier_num.include?('_CL')

        pricing = PricingDesc.new
        (1..5).each do |i|
          break if (qty = row["Pricing-Qty#{i}"]).blank?
          pricing.add(qty, row["Pricing-Price#{i}"], row["Pricing-Code#{i}"])
        end
        pricing.maxqty

        pd.decorations = [DecorationDesc.none]
        
        
        colors = row['Available Colors'] ? row['Available Colors'].split(/\s*,\s*/).collect { |c| c.split(' ').collect { |w| w.capitalize }.join(' ') } : ['']
        
        image_list_path = WebFetch.new("http://www.crownprod.com/includes/productimages.php?browse&itemno=#{supplier_num.gsub(/_CL$/, '')}").get_path
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
          puts " Using default image: #{supplier_num}"
          color_image_map = {}
          pd.images = [ImageNodeFetch.new('default',
                                          "http://www.crownprod.com/images/items/BRIGTEYE_CL_xl.jpg")]
        else
          color_image_map, color_num_map = match_image_colors(images, colors, supplier_num)
          pd.images = color_image_map[nil]
        end
        
        pd.variants = colors.collect do |color|
          VariantDesc.new(:supplier_num => "#{supplier_num}-#{color}",
                          :properties => { 'color' => color },
                          :images => color_image_map[color] || [],
                          :pricing => pricing)
        end
      end
    end
  end
end
