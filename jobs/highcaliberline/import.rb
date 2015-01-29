# -*- coding: utf-8 -*-

require 'csv'

# Supplier num fix: update products set supplier_num = regexp_replace(supplier_num, '-', '') where supplier_id = 57;

class HighCaliberLine < GenericImport
  def initialize(file)
    if file
      @src_files = [File.join(JOBS_DATA_ROOT, file)]
    else
      @src_urls = ['http://highcaliberline.com/script/product_data_download.php']
    end

    super "High Caliber Line"
  end

  def imprint_colors
    %w(186 021 Process\ Yellow 123 161 347 342 281 Process\ Blue Reflex\ Blue 320 266 225 195 428 430 White Black 877 872)
  end

  def parse_products
    puts "FTP Images"
    @image_list = get_ftp_images('highcaliberline.hostedftp.com',
                                 ['~artwork/HCL_Image-Library'],
                                 /^(?!.*psd$)/i) do |path, file|
      next nil unless /^([a-z]{1,3}-?\d{1,4}[a-z]{0,4})(?:[_-](.+))?\.jpg$/i =~ file
      supplier_num, desc = $1, $2
      id = path.split('/').last + '/' + (desc || '')
      [id, supplier_num.gsub('-', ''), desc && desc.split('_').first, id.downcase.include?('blank') ? 'blank' : nil]
    end

    lanyard_color_list = %w(black brown burgundy forest\ green gray green light\ blue navy\ blue orange purple red reflex\ blue teal white yellow).collect do |name|
      [name.capitalize, name.capitalize, ImageNodeFile.new(name, File.join(JOBS_DATA_ROOT, 'HighCaliber-Lanyard-Swatches', "#{name}.jpg"))]
    end

    name_list = %w(Maroon Red Grey Orange Gold Yellow Teal Bright\ Pink Bright\ Green Pink Bright\ Orange Purple Green Deep\ Royal Royal Navy White Charcoal Black)
    pms_list = %w(209 200 429 165 123 YELLOW 3165 812 802 RHOqDAMINE\ RED 804 VIOLET 3308 286 293 289 WHITE 432 PROCESS\ BLACK)
    neoprene_color_list = name_list.zip(pms_list).collect { |n, p| [n, "#{n} (PMS #{p})"] }

    puts "Parsing"
    CSV.foreach(@src_files.first, encoding: "ISO-8859-1", :headers => :first_row) do |row|
      next if row['Item Status'] == 'Disabled on Website'
      ProductDesc.apply(self) do |pd|
        pd.merge_from_object(row, {
                               'supplier_num' => 'HCL Item#',
                               'name' => 'Item Name' })
             
        puts "Product: #{pd.supplier_num}"
        
        pd.name.gsub!(/\s+/, ' ')
      
        if description = row['Description']
          pd.description = description.gsub(/\s*([.?!])\s+/, "\\1\n").strip
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

        pd.tags = TagsDesc.new
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


        # Decorations
        pd.decorations = overseas ? [] : [DecorationDesc.none]

        no_ltm = false

        if decoration_str = row['Decoration']
          decoration_list = decoration_str.split(/,|(?:\s\s+)/)
          loop do
            imprint_part = decoration_list.first
            break unless /^Imprint Area:(?:\s*\((.+)\):)?\s*(.+?)(?:\s*\((.+?)\))?$/ === imprint_part
            decoration_list.shift

            location, qualify = $1, $3
            imprint_area = $2 && parse_area($2.gsub("''", '"'))
            if imprint_area
              if imprint_area.include?(:length)
                warning 'Imprint Area has Length', imprint_part
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

          no_ltm = decoration_list.find { |s| s.include?('minimum') }

          #puts "Remain: #{decoration_list.inspect}"
        end

        # Package Info
        { weight: 'Carton Weight',
          units:  'Carton Qty',
          height: 'Height',
          width:  'Width',
          length: 'Length' }.each do |attr, col|
          if row[col] and row[col] != 'N/A' and Float(row[col]) != 0.0
            pd.package.send("#{attr}=", row[col])
          end
        end
      
        
        # Price Info (common to all variants)
        (1..5).each do |num|
          qty = (num == 1) ? row["Item MOQ"] : row["Qty #{num}"]
          price = row["Price #{num}"]
          qty = qty.gsub(/[^0-9]+$/, '') if qty.is_a?(String)
          next if qty.blank? or price.blank?
          pd.pricing.add(qty, price, 'R')
        end
        
        if overseas
          pd.pricing.costs.shift # Remove first column
        else
          pd.pricing.eqp_costs
          pd.pricing.ltm(25.00) unless no_ltm

          unless a_to_z_product or wow_product #or tags.include?('Closeout')
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
          pd.properties['dimension'] = parse_dimension(dimension) || dimension.strip.gsub(/\s\s\s+/, '  ').gsub('&quot;','"')
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

        unless @image_list[pd.supplier_num]
          db_id = Integer(row['Web Link'].split('/').last)
          wf = WebFetch.new("http://highcaliberline.com/downloadimage/downloadimage/download/product_id/#{db_id}/")
          path = wf.get_path
          file = Zip::File.open(path)
          @image_list[pd.supplier_num] = file.map do |e|
            id = e.name.split('/').last
            [ImageNodeZip.new(id, path, e.name), id]
          end
        end

        color_image_map, color_num_map = match_colors(color_list.compact, :prune_colors => true)
        pd.images = color_image_map[nil] || []
        
        pd.variants = color_list.uniq.collect do |id|
          VariantDesc.new(:supplier_num => (pd.supplier_num + (id ? "-#{id}" : ''))[0..63],
                          :images => (id && color_image_map[id]) || [],
                          :properties => { 'color' => id })
        end
      end
    end
  end
end
