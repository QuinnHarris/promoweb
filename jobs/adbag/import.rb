# ToDO
# Quantity on decoration pricing

class AdbagProdXLS < GenericImport
  def initialize
    @src_file = File.join(JOBS_DATA_ROOT, '2012AABCATALOG.xlsx')
    super 'American Ad Bag'
  end


  def fetch_parse?
    # if File.exists?(@src_file) and
    #     File.mtime(@src_file) >= (Time.now - 7.day)
    #   puts "File Fetched today"
    #   return false
    # end
    
    # puts "Starting Fetch"
    
    # agent = Mechanize.new
    # page = agent.get('http://crownprod.com/includes/productdata.php')
    # form = page.forms.first
    # form.action = '/' + form.action
    # page = agent.submit(form)
    
    # page.save_as @src_file
    
    # puts "Fetched"
    # true
  end
  def parse_products
    wksheets = RubyXL::Parser.parse(@src_file)
    ws = wksheets[0]
    setups = {}
    setups.default = []
    running = {}
    ws.rows.each do |row|
      debugger
      ProductDesc.apply(self) do |pd|
        pd.supplier_num = row["ITEMNO"]
        pd.name = row["PRODUCT NAME"]
        # pd.description = row[2].value+" "+row[3].value
        # pd.supplier_categories = [row[5].value]
        pd.package.weight =  Float(row["PACK WEIGHT"])
        pd.package.units =  row["PACK SIZE"]
        pd.package.height =  Float(row["PACK HEIGHT"])
        pd.package.length = row["PACK LENGTH"].value.to_i
        pd.package.width = row["PACK WIDTH"].value.to_i
        pd.lead_time = row["LEAD TIME"].value.to_i
        pd.tags = []
      end
    end  
#     # Remove duplicate setups and choose highest price
#     setups.each do |sup_num, list|
#       @supplier_num = sup_num
#       list = list.uniq.group_by { |h| h[:technique] }.collect do |tech, hashs|
#         next unless hashs.length > 1
#         warning "Duplicate Setups", hashs.inspect
#         hashs.sort_by { |h| h[:fixed] }.last
#       end.compact
#       setups[sup_num] = list unless list.empty?
#     end


#     ws = ss.worksheet(2)
#     ws.use_header
#     sales = {}
#     ws.each(1) do |row|
#       next unless row['Sale?'] == 'Y'
#       next unless Float(row['Sale Qty']) > 0.0
#       pricing = PricingDesc.new
#       pricing.add(row['Sale Qty'], row['Sale Price'], row['Sale Code'])
#       sup_num = row['Item# (SKU)'].to_s.strip
#       sales[sup_num] = pricing
#     end

#     variations = {}
#     variations['info_list'] = {}
#     variations['info_list'].default = []

#     ws = ss.worksheet(0)
#     ws.use_header
#     ws.each(1) do |row|
#       next unless @supplier_num = row['Item# (SKU)']

#       puts
#       puts "Product: #{@supplier_num}"

#       %w(Price\ Includes).each do |name|
#         variations[name] ||= {}
#         value = row[name]
#         variations[name][value] = (variations[name][value] || []) + [@supplier_num]
#       end

#       ProductDesc.apply(self) do |pd|
#         pd.supplier_num = @supplier_num
#         pd.name = row['Item Name']
#         pd.description = (row['Product Description'] || '').gsub(".", ".\n").strip
#         pd.supplier_categories = [[row['Product Categories'].strip]]
#         pd.package.weight = row['Shipping Weight'] && Float(row['Shipping Weight'])
#         pd.package.units = row['Shipping Quantity'] && row['Shipping Quantity'].to_i
#         pd.tags = []

#         pd.tags << 'Closeout' if @supplier_num.include?('_CL')

#         info_list = (row['Additional Info'] || '')
#           .scan(/\s*(?:(?:\d\.\s*(.+?(?:[.?!]|$)))|(.+?(?:[.?!]|$)))\s*/).collect { |a, b| s = (a || b).strip; s.blank? ? nil : s }
#           .compact.collect { |s| s.gsub(/\s*\d\.$/,'') }
#         info_list.each do |str|
#           variations['info_list'][str] += [@supplier_num]
#         end
#         if info_list.find { |i| i.length <= 2 }
#           puts "INFO: #{row['Additional Info'].inspect} : #{info_list.inspect}"
#         end


#         if pricing = sales[@supplier_num]
#           pd.tags << 'Special'
#           e = (1..5).collect { |i| row["Pricing-Qty#{i}"] && Integer(row["Pricing-Qty#{i}"]) }.compact.max
#           pricing.maxqty(e*2)
#         else
#           pricing = PricingDesc.new
#           (1..5).each do |i|
#             break if (qty = row["Pricing-Qty#{i}"]).blank?
#             pricing.add(qty, row["Pricing-Price#{i}"], row["Pricing-Code#{i}"])
#           end
#           pricing.maxqty
#         end
#         info_list.delete(e) if e = info_list.find { |e| /Less than.+not avalable/i === e }
#         pricing.ltm(40.0, 1) unless e

#         info_list.delete_if do |s|
#           next true if s.include?('on PO')
#           not (/^[A-Z].{5}.+?\.$/ === s)
#         end
#         pd.description += info_list.collect { |s| "\n" + s }.join


#         puts "Area: #{row['Imprint Area']}"
#         locations = parse_areas(row['Imprint Area'])
#         locations.each do |imprint|
#           puts "  #{imprint.inspect}"
#         end

#         includes = []
#         row['Price Includes'].split(',').each do |str|
#           location = nil
#           if /^(.+?)\s+on\s+(.+?)\.?$/ === str
#             str = $1
#             location = $2
#           end

#           hash = case str
#                  when /(\d)-(\d) color/i
#                    { :technique => 'Pad Print', :limit => Integer($2) }
#                  when /digital\s+color/i, /4\s+|-color\s+process/i
#                    { :technique => 'Photo Transfer' }
#                  when /dome/i
#                    { :technique => 'Dome' }
#                  when /laser/i
#                    { :technique => 'Laser Engrave' }
#                  when /embroider/i
#                    { :technique => 'Embroidery' }
#                  when /deboss/i
#                    { :technique => 'Deboss' }
#                  when /onc?e\s+color/i
#                    { :limit => 1 }
#                  when /\d side/i
#                    {}
#                  else
#                    warning 'Unkown Price Includes', "#{row['Price Includes']} => #{str}"
#                    {}
#                  end
#           includes << hash.merge(:location => location || '')
#         end if row['Price Includes']

#         puts "Includes: #{row['Price Includes']}"
#         includes.each do |imprint|
#           puts "  #{imprint.inspect}"
#         end

#         puts "Setups:"
#         setups[@supplier_num].each do |imprint|
#           puts "  #{imprint.inspect}"
#         end

#         puts "Running: #{running[@supplier_num].inspect}"

#         combos = [locations, includes, setups[@supplier_num], [running[@supplier_num]]]
#         puts "PARTS: #{combos.inspect}"
# #        pd.decorations = [DecorationDesc.none]
#         pd.decorations = decorations_from_parts(combos, [], :minimal => true)

        
        
#         colors = row['Available Colors'] ? row['Available Colors'].split(/\s*,\s*/).collect { |c| c.split(' ').collect { |w| w.capitalize }.join(' ') } : ['']
        
#         image_list_path = WebFetch.new("http://www.crownprod.com/includes/productimages.php?browse&itemno=#{@supplier_num.gsub(/_CL$/, '')}").get_path
#         doc = Nokogiri::HTML(open(image_list_path))
#         images = doc.xpath("//td[@class='hires_download_file']/a").collect do |a|
#           href = a.attributes['href'].value
          
#           unless /file=((?:(.+?)%5C)?(.+?(?:[+_](.+?))?)\.jpg)$/i === href
#             raise "Unknown href: #{href}"
#           end
#           desc = $4 || $3
          
#           [ImageNodeFetch.new($1, href, ($2 == 'Blanks') ? 'blank' : nil), desc.gsub(/\+|_/,' ').strip]
#         end
        
#         if images.empty?
#           puts " Using default image: #{@supplier_num}"
#           color_image_map = {}
#           pd.images = [ImageNodeFetch.new('default',
#                                           "http://www.crownprod.com/images/items/BRIGTEYE_CL_xl.jpg")]
#         else
#           color_image_map, color_num_map = match_image_colors(images, colors, :prune_colors => true)
#           pd.images = color_image_map[nil] || []
#         end
        
#         pd.variants = colors.collect do |color|
#           VariantDesc.new(:supplier_num => "#{@supplier_num}-#{color}",
#                           :properties => { 'color' => color },
#                           :images => color_image_map[color] || [],
#                           :pricing => pricing)
#         end
#       end
#     end

#     variations.each do |name, hash|
#       puts "#{name}:"
#       hash.to_a.sort_by { |k, v| k || '' }.each do |elem, list|
#         puts "  #{list.length}: #{elem.inspect}" # : #{list.join(',')}"
#       end
#     end
  end
end
