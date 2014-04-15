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
      parse_file("2014 Master Excel List.xlsx")
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
    ws = RubyXL::Parser.parse(File.join(JOBS_DATA_ROOT, file)).worksheets[ws_num]
    puts ws.use_header(0).inspect
    (1..(ws.sheet_data.size)).each do |idx|
      row = ws.sheet_data[idx]

      if row['Item Descrition'].include?('Texas')
        puts "Excluding Product: #{row['Product Code']}"
        next
      end

      ProductDesc.apply(self) do |pd|
        pd.merge_from_object(row, {
                               'supplier_num' => 'Item# w/Photo',
                               'name' => 'Item Name' })
             
        puts "Product: #{pd.supplier_num}"
        
        pd.name.gsub!(/\s+/, ' ')
      
        if description = row['Item Descrition']
          pd.description = description.gsub("\uFEFF", '').gsub(/\s+/,' ').gsub(/\s?\.\s/,"\n").gsub(/\s?•\s/,"\n").strip
        end

        # Categories
#        begin
#          pd.supplier_categories = [%w(Category Sub\ Category).collect do |catname|
#            str = row[catname]
#            str && str.strip.gsub('&amp;','&').gsub(/\s+/, ' ')
#          end.compact]
#        rescue Spreadsheet::Excel::Row::NoHeader
#          pd.supplier_categories = [[]]
#        end
        pd.supplier_categories = [['UNKOWN']]

        pd.tags = TagsDesc.new(tags)
        laser_engrave = wow_product = nil
        if false #highlight = row['Highlightimage']
          highlight.split(/\s*,\s*/).each do |elem|
            case elem
            when 'New'
              pd.tags << 'New'
            when 'Made In USA', 'USA'
              pd.tags << 'MadeInUSA'
            when 'Green'
              pd.tags << 'Eco'
            when 'Laser Engraving', 'Standard Laser Engraving', 'Free Optional Laser Engraving'
              laser_engrave = true
            when '24 Hours'
              pd.lead_time.rush = 1
            when 'WOW'
              wow_product = true
            else
              warning 'Unknown Highlight', elem
            end
          end
        end

        cat_string = pd.supplier_categories.join.downcase
        overseas = (/(?:Overseas)|(?:Factory)/i === cat_string)
        a_to_z_product = (/A to Z Line/i === cat_string)

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
        if imprint_str = row['Imprint Area']
          imprint_str.split(/,|(?:\s{2,3})/).each do |imprint_part|
            unless /^(?:(.+?):)?\s*(.+?)(?:(.+?)\))?$/ === imprint_part
              puts "Imprintt: #{imprint_str.inspect}"
            end
            location, qualify = $1, $3
            imprint_area = $2 && parse_area($2)
            if imprint_area
              if imprint_area.include?(:length)
                warning 'Imprint Area has Length', imprint_str
              else
                imprint_area.delete(:left); imprint_area.delete(:right)
                pd.decorations << DecorationDesc.new(:technique => 'Screen Print',
                                                     :limit => 4, :location => location || '')
                  .merge!(imprint_area)
                pd.decorations << DecorationDesc.new(:technique => 'Laser Engrave',
                                                     :limit => 4, :location => location || '')
                  .merge!(imprint_area) if laser_engrave
              end
            end
          end
        end
        
      
        # Package Info
        if weight = Float(row['Carton Weight']) and weight != 0.0
          pd.package.weight = weight
        end
        if units = Integer(row['Carton Qty']) and units != 0
          pd.package.units = units
        end
        pd.package.merge_from_object(row, { 'height' => 'Height',
                                       'width' => 'Width',
                                       'length' => 'Length' } )
      
        
        # Price Info (common to all variants)
        (1..5).each do |num|
          qty = (num == 1) ? row["Min. Qty"] : row["Qty#{num}"]
            next if qty.blank?
          qty = qty.gsub(/[^0-9]+$/, '') if qty.is_a?(String)
          pd.pricing.add(qty, row["Prc#{num}"], 'R')
        end
        
        if overseas
          pd.pricing.costs.shift # Remove first column
        else
          pd.pricing.eqp_costs
          pd.pricing.ltm(25.00)

          unless a_to_z_product or wow_product or tags.include?('Closeout')
            pd.pricing.costs.last[:marginal] *= 0.95
          end
        end
        pd.pricing.maxqty
        

        # Leed Time
        begin
          case production_time = row['Standard Production Time'].strip
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
        rescue NoHeader
        end
      
        if dimension = row['Item Size']
          pd.properties['dimension'] = parse_dimension(dimension) || dimension.strip.gsub(/\(.+?\)/,'').gsub('&quot;','"')
        end
      
        if color_str = row['Item Color']
          color_str = color_str.gsub("\uFEFF", '').strip
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
