# -*- coding: utf-8 -*-

class HighCaliberLine < GenericImport
  def initialize(date)
    @date = date
    @domain = "www.highcaliberline.com"
    @image_list = {}
    super "High Caliber Line"
  end

  def imprint_colors
    %w(186 021 Process\ Yellow 123 161 347 342 281 Process\ Blue Reflex\ Blue 320 266 225 195 428 430 White Black 877 872)
  end

  def parse_products
    file_name = cache_file("#{@supplier_name}_Images")
    @image_list = cache_read(file_name) if cache_exists(file_name)

    begin
      parse_file("HCL-US Master Excel Final on #{@date}.xls")
#      parse_file("HCL-US Closeout Master Excel on #{@date}.xls", 'Closeout')
 #     parse_file("HCL-US Closeout Master Excel on #{@date}.xls", 'Closeout', 1)
    ensure
      cache_write(file_name, @image_list)
    end
  end

  @@image_path = "http://www.highcaliberline.com/Product%20Image/Zoom/900x900"
  def get_images(product_id)
    return @image_list[product_id] if @image_list.has_key?(product_id)
    puts "Getting Image List for #{product_id}"
    uri = URI.parse("#{@@image_path}/Logo/#{product_id}/")
    begin
      txt = uri.open.read
      @image_list[product_id] = txt.scan(/<a href="([\w-]+\.jpg)">/).flatten
    rescue
      puts "Failed to get image #{product_id}"
      @image_list[product_id] = []
    end
  end

  def parse_file(file, tags = [], ws_num = 0)
    lanyard_color_list = %w(black brown burgundy forest\ green gray green light\ blue navy\ blue orange purple red reflex\ blue teal white yellow).collect do |name|
      [name.capitalize, name.capitalize, ImageNodeFile.new(name, File.join(JOBS_DATA_ROOT, 'HighCaliber-Lanyard-Swatches', "#{name}.jpg"))]
    end

    name_list = %w(Maroon Red Grey Orange Gold Yellow Teal Bright\ Pink Bright\ Green Pink Bright\ Orange Purple Green Deep\ Royal Royal Navy White Charcoal Black)
    pms_list = %w(209 200 429 165 123 YELLOW 3165 812 802 RHODAMINE\ RED 804 VIOLET 3308 286 293 289 WHITE 432 PROCESS\ BLACK)
    neoprene_color_list = name_list.zip(pms_list).collect { |n, p| [n, "#{n} (PMS #{p})"] }

    puts "Parsing: #{file} #{ws_num}"
    ws = Spreadsheet.open(File.join(JOBS_DATA_ROOT, file)).worksheet(ws_num)
    puts ws.use_header(1).inspect
    ws.each(2) do |row|
      if row['Description'].include?('Texas')
        puts "Excluding Product: #{row['Product ID']}"
        next
      end

      ProductDesc.apply(self) do |pd|
        pd.merge_from_object(row, {
                               'supplier_num' => 'Product ID',
                               'name' => 'Product Name' })
             
        puts "Product: #{pd.supplier_num}"
        
        pd.name.gsub!(/\s+/, ' ')
      
        if description = row['Description']
          pd.description = description.gsub(/\s+/,' ').gsub(/\s?\.\s/,"\n").gsub(/\s?•\s/,"\n").strip
        end

        # Categories
        begin
          pd.supplier_categories = [%w(Category Sub-Categories).collect do |catname|
            str = row[catname]
            str && str.strip.gsub('&amp;','&').gsub(/\s+/, ' ')
          end.compact]
        rescue Spreadsheet::Excel::Row::NoHeader
          pd.supplier_categories = [[]]
        end

        tags = []
        if ws.header_map['Features'] and row['Features']
          tags << 'New' if row['Features'].include?('New')
          tags << 'Eco' if row['Features'].include?('Bio')
          tags << 'MadeInUSA' if row['Features'].include?('usa')
        end

        cat_string = pd.supplier_categories.join.downcase
        tags << 'Eco' if cat_string.include?('eco')
        tags << 'MadeInUSA' if cat_string.include?('usa')
        pd.tags = tags.uniq

        overseas = (/(?:Overseas)|(?:Factory)/i === cat_string)


        if prod = @product_list.find { |p| p.supplier_num == pd.supplier_num }
          prod.supplier_categories = (prod.supplier_categories + pd.supplier_categories).uniq
          prod.tags = (prod.tags + pd.tags).uniq
          puts " Same product: Added Cat: #{pd.supplier_categories.inspect} => #{prod.supplier_categories.inspect}, Tag: #{pd.tags.inspect} => #{prod.tags.inspect}"
          next false
        end


        # Image
        image_list = ["Group/#{pd.supplier_num}.jpg"] +
          get_images(pd.supplier_num).collect { |n| "Logo/#{pd.supplier_num}/#{n}" }
        pd.images = image_list.collect { |img| ImageNodeFetch.new(img, "#{@@image_path}/#{img}") }      
        

        # Decorations
        pd.decorations = overseas ? [] : [DecorationDesc.none]
        if imprint_str = row['Imprint Size']
          laser = ws.header_map['Features'] && row['Features'].to_s.include?('Laser Engrav')

          imprint_str.split(/,|(?:\s{2,3})/).each do |imprint_part|
            unless /^(?:(.+?):)?\s*(.+?)(?:(.+?)\))?$/ === imprint_part
              puts "Imprintt: #{imprint_str.inspect}"
            end
            location, qualify = $1, $3
            imprint_area = $2 && parse_dimension($2)
            puts "Imprint: #{imprint_str.inspect} => #{imprint_area.inspect}" unless imprint_area
            if imprint_area
              pd.decorations << DecorationDesc.new(:technique => 'Screen Print',
                                                   :limit => 4, :location => location || '')
                .merge!(imprint_area)
              pd.decorations << DecorationDesc.new(:technique => 'Laser Engrave',
                                                   :limit => 4, :location => location || '')
                .merge!(imprint_area) if laser
            end
          end
        end
        
      
        # Package Info
        if weight_str = row['Weight']
          unless /^\s*(\d+)\s*lbs\s*\/\s*(\d+)\s*pcs?/ === weight_str
            puts  " !!! Unknown Weight: #{weight_str.inspect}"
          end
          pd.package.weight = $1.to_f
          pd.package.units = $2 && $2.gsub(',','').to_i
        end
        %w(height width length).each do |name|
          val = Float(row["#{name.capitalize} (Inch)"])
          pd.package[name] = val unless val == 0.0
        end
      

        # Price Info (common to all variants)
        if ws.header_map['Minimum Qty']
          #        qty = row["Minimum Qty"]
          #        price_list =
          #          [{ :minimum => Integer(qty.is_a?(String) ? qty.gsub(/[^0-9]/,'') : qty),
          #             :marginal => Money.new(Float(row['Price Reduced'])),
          #             :fixed => Money.new(0) }]
          raise "Minimum Quantity"
        else
          (1..5).each do |num|
            qty = row["Qty #{num}"]
            next if qty.blank?
            qty = qty.gsub(/[^0-9]+$/, '') if qty.is_a?(String)
          pd.pricing.add(qty, row["Price #{num}"])
          end
        end
        
        pd.pricing.eqp
        pd.pricing.maxqty
        pd.pricing.ltm(25.00) unless overseas
        

        # Leed Time
        begin
          case production_time = row['Production Time'].strip
          when /(\d{1,2})(?:-(\d{1,2}))?\s*(Day|Week)/i
            mult = ($3.downcase == 'day') ? 1 : 5
            min, max = Integer($1)*mult, Integer($2 || $1)*mult
          when /^((?:2[34])|(?:48))\s*H(ou)?r/i
            min = max = (Integer($1) + 1) / 24
          else
            min = max = nil
            puts "Unknown: #{production_time}"
          end
          pd.lead_time.normal_min = min
          pd.lead_time.normal_max = max
        rescue Spreadsheet::Excel::Row::NoHeader
        end
      
        if dimension = row['Size']
          pd.properties['dimension'] = parse_dimension(dimension) || dimension.gsub(/\(.+?\)/,'').gsub('&quot;','"')
        end
      
        if color_str = row['Colors']
          if /Standard Lanyard.+colors\.?(?:&lt;br&gt;)?(.*)/i === color_str
            pd.description += "\n#{$1}" unless $1.blank?
            color_list = lanyard_color_list
          elsif pd.description.downcase.include?('neoprene') and color_str.include?('19')
            color_list = neoprene_color_list
          else
            if color_str.include?('and') and color_str.include?('or')
              color_list = color_str.split(/\s*(?:(?:\s+or\s+)|,|\.|(?:Trims?\.?))\s*/)
            else
              color_list = color_str.split(/\s*(?:(?:\s+or\s+)|(?:\s+and\s+)|,|\.|(?:Trims?\.?))\s*/)
            end
          end
        else
          color_list = []
        end

        if color_list.empty? # Always need one variant      
          if /Lanyard/i === pd.name
            color_list = lanyard_color_list
          else
            color_list = [nil]
          end
        end
        
        pd.variants = color_list.uniq.collect do |id, name, swatch|
          VariantDesc.new(:supplier_num => (pd.supplier_num + (id ? "-#{id}" : ''))[0..63],
                          :images => [],
                          :properties => { 'color' => name || id, 'swatch' => swatch })
        end
      end
    end
  end
end
