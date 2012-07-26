class CrownProdXLS < GenericImport
  def initialize
    @src_file = File.join(JOBS_DATA_ROOT, 'CrownProductData.xls')
    super 'Crown Products'
  end

  def fetch
    if File.exists?(@src_file) and
        File.mtime(@src_file) >= (Time.now - 24*60*60)
      puts "File Fetched today"
      return
    end
    
    puts "Starting Fetch"
    
    agent = Mechanize.new
    page = agent.get('http://crownprod.com/includes/productdata.php')
    form = page.forms.first
    form.action = '/' + form.action
    page = agent.submit(form)
    
    page.save_as @src_file
    
    puts "Fetched"
  end


  def parse_products
    fetch

    ss = Spreadsheet.open(@src_file)


    ws = ss.worksheet(0)
    ws.use_header
    ws.each(1) do |row|
      next unless supplier_num = row['Item# (SKU)']

      product_data = {
        'supplier_num' => supplier_num,
        'name' => row['Item Name'],
        'description' => (row['Product Description'] || '').gsub(".", ".\n").strip,
        'supplier_categories' => [[row['Product Categories'].strip]],
        'package_weight' => row['Shipping Weight'] && Float(row['Shipping Weight']),
        'package_units' => row['Shipping Quantity'] && row['Shipping Quantity'].to_i,
        'tags' => []
      }

      product_data['tags'] << 'closeout' if supplier_num.include?('_CL')

      prices = []
      costs = []
      (1..5).each do |i|
        qty = row["Pricing-Qty#{i}"]
        break if qty.blank?

        base = {
          :fixed => Money.new(0),
          :minimum => Integer(qty) }

        discount = convert_pricecode(row["Pricing-Code#{i}"])
        price = Money.new(Float(row["Pricing-Price#{i}"]))
        prices << base.merge(:marginal => price)
        costs << base.merge(:marginal => price * (1.0 - discount) )
      end
      costs << { :minimum => costs.last[:minimum] * 2 } unless costs.empty?

      common_variant = { 'prices' => prices, 'costs' => costs }


      decorations = [{
          'technique' => 'None',
          'location' => ''
        }]
      product_data['decorations'] = decorations


      colors = row['Available Colors'] ? row['Available Colors'].split(/\s*,\s*/).collect { |c| c.split(' ').collect { |w| w.capitalize }.join(' ') } : ['']
      
      image_list_path = WebFetch.new("http://www.crownprod.com/includes/productimages.php?browse&itemno=#{supplier_num.gsub(/_CL$/, '')}").get_path
      doc = Nokogiri::HTML(open(image_list_path))
      images = doc.xpath("//td[@class='hires_download_file']/a").collect do |a|
        href = a.attributes['href'].value
 
        unless /file=((?:(.+?)%5C)?.+?(?:[+_](.+?))?\.jpg)$/i === href
          raise "Unknown href: #{href}"
        end

        [ImageNodeFetch.new($1, href, ($2 == 'Blanks') ? 'blank' : nil), $3 ? $3.gsub(/\+|_/,' ').strip : '']
      end

      if images.empty?
        puts " Using default image: #{supplier_num}"
        color_image_map = {}
        product_data['images'] = [ImageNodeFetch.new('default',
                                                     "http://www.crownprod.com/images/items/BRIGTEYE_CL_xl.jpg")]
      else
        color_image_map, color_num_map = match_image_colors(images, colors, supplier_num)
        product_data['images'] = color_image_map[nil]
      end

      product_data['variants'] = colors.collect do |color|
        { 'supplier_num' => "#{supplier_num}-#{color}",
          'properties' => { 'color' => color },
          'images' => color_image_map[color],
        }.merge(common_variant)
      end

      add_product(product_data)
    end


  end

end
