# -*- coding: utf-8 -*-
require 'csv'

# TODO
# No less than minimum on blank;
# Different pricing on embroidery
# Unit predicated packaging

class HitPromoCSV < GenericImport  

  def initialize
    year = Time.now.year
    puts "Starting Fetch for #{year}"
    @src_files = 
      ["http://www.hitpromo.net/fs/documents/hit_product_data_#{year}.csv",
       "http://outlet.hitpromo.net/fs/documents/hit_outlet_data_#{year}.csv"].collect do |url|
      WebFetch.new(url).get_path(Time.now - 1.day)
    end
    @package_file = File.join(JOBS_DATA_ROOT, 'HitPackingData.xls')
    @rush_file = File.join(JOBS_DATA_ROOT, 'HitRushService.xls')
    super 'Hit Promotional Products'
  end

#%w(colors_available imprint_colors approximate_size imprint_area set_up_charge multi_color_imprint packaging multi_panel_imprint second_side_imprint fob_zip second_handle_imprint please_note embroidery_information thread_colors tape_charge sizes approximate_bag_size optional_imprint second_positon non_woven_items label_color four_color_process optional_imprint_area second_position_imprint highlighters imprint catalog_page colors)

  @@decoration_map = {
    'debossed' => 'Deboss',
    'embroidered' => 'Embroidery',
    'embroidery' => 'Embroidery',
    'laser' => 'Laser Engrave',
    'laser engrave' => 'Laser Engrave',
    'laser engraved' => 'Laser Engrave',
    'laser engraving' => 'Laser Engrave',
    'optional embroidered' => 'Embroidery',
    'oval dome' => 'Dome',
    'square dome' => 'Dome',
    'pad-print' => 'Pad Print',
    'silk-screen' => 'Screen Print',
    'silk-screen or transfer' => ['Screen Print', 'Photo Transfer'],
    'silk-screened' => 'Screen Print',
    'Transfer' => 'Photo Transfer',
    '1 - 4 color process method' => 'Color Process',
    '1-4 color process' => 'Color Process'
    # insert into decoration_techniques (name, unit_name, unit_default) values ('Color Process', 'color', 1);
  }
  cattr_reader :decoration_map
 
  def parse_products
    # Package File
    package_list = {}
    ws = Spreadsheet.open(@package_file).worksheet(0)
    ws.use_header
    ws.each(1) do |row|
      supplier_num = row['Product #'].to_s.strip
      desc = PackageDesc.new(:weight => row['prpWeight'],
                             :units => row['prpQuantityPerBox'],
                             :length => row['prpBoxLength'],
                             :width => row['prpBoxWidth'],
                             :height => row['prpBoxHeight'])
      if !package_list[supplier_num] or package_list[supplier_num].units > desc.units
        package_list[supplier_num] = desc
      end
    end

    rush_list = Set.new
    ws = Spreadsheet.open(@rush_file).worksheet(0)
    ws.use_header
    ws.each(1) do |row|
      rush_list << row['number'].to_s.strip
    end

    common_list = %w(product_name new description category product_photo colors_available imprint_colors approximate_size imprint_area set_up_charge multi_color_imprint packaging multi_panel_imprint second_side_imprint fob_zip second_handle_imprint please_note embroidery_information thread_colors tape_charge sizes approximate_bag_size optional_imprint precious_metal_imprint for_gold_banding for_halo battery second_positon non_woven_items label_color four_color_process optional_imprint_area second_position_imprint highlighters refills optional_carabiner imprint catalog_page optional_pen colors)

    price_list = %w(discount_code) + (1..8).collect { |n| ["price#{n}", "quantity#{n}"] }.flatten

    product_merge = ProductRecordMerge.new(price_list, common_list, '--')

    normal_file, closeout_file = @src_files
    [[normal_file, false],
     [closeout_file, true]
    ].each do |file, closeout|
      CSV.foreach(file, :headers => :first_row, :col_sep => ' ', :quote_char => "'") do |row|
        unless /^(.+?)((B Blank)|(E Embroidered)|(D .*Debossed)|(L Laser Engrave)|(S .*Silk-Screen)|(S Pad-Print)|(T Transfer))?$/ === row['product_sku']
          raise "Bad Reg"
        end
        supplier_num = $1.strip
        postfix = $2 && $2[0]

        if closeout and product_merge.include?(supplier_num)
          puts "CLOSEOUT MATCHING: #{supplier_num}"
          supplier_num += 'OUTLET'
        end
        
        uhash = product_merge.merge(supplier_num, row, :common => { 'closeout' => closeout })
        uhash['postfix'] = postfix
      end
    end

    price_preference = %w(L S D T E B)
    
#    variations = {}

    product_merge.each do |supplier_num, unique, common|
      ProductDesc.apply(self) do |pd|
        @supplier_num = supplier_num
        puts
        puts "Product: #{supplier_num}"
        pd.supplier_num = supplier_num
        pd.name = common['product_name']
        pd.supplier_categories = [[common['category'].strip]]
        pd.tags = []

        pd.description =
          (common['description'] ? common['description'].split(/\s*\|\s*/) : []) +
          (common['please_note'] ? common['please_note'].gsub(/\s*((<.+?>)|[^[[:ascii:]]])\s*/,' ').split(/\s*\n\s*/) : []) +
          %w(precious_metal_imprint for_gold_banding for_halo refills optional_carabiner optional_pen battery).collect do |name|
          next unless common[name]
          str = name.split('_').collect { |w| w.capitalize }.join(' ') + ": "
          str << common[name].gsub(/<a href=".+?">(\d+)<\/a>/) do |str|
            product = get_product($1)
            "<a href='#{product.web_id}'>#{product.name}</a>"
          end
          str
        end.compact
        
        if common['closeout']
          pd.tags << 'Closeout' 
        else
          pd.tags << 'New' if common['new'] == 'yes'
        end

        # Packaging
        pd.package = package_list[supplier_num] if package_list[supplier_num]

        # Lead Times
        pd.lead_time.normal_min = 5
        pd.lead_time.normal_max = 10
        if rush_list.include?(supplier_num)
          pd.lead_time.rush = 3
          pd.lead_time.rush_charge = 0
        end


        # Prices
        price_string = unique.sort_by { |s| price_preference.index(s['postfix']) }.first
        (1..8).each do |i|
          qty = price_string["quantity#{i}"]
          break if qty.blank? or qty == '--'
          pd.pricing.add(qty, price_string["price#{i}"])
        end
        pd.pricing.apply_code(price_string['discount_code'])
        unless pd.supplier_categories.flatten.include?('Ceramics') or
            common['embroidery_information']
          pd.pricing.ltm(40.0)
        end
        pd.pricing.maxqty
        
        # Can list multiple dimensions e.g. "16" W x 14 ½" H • Pouch: 4 ½" W x 5" H"
        dimension = common['approximate_size'] || common['approximate_bag_size']
        pd.properties['dimension'] = parse_dimension(dimension) if dimension


        pd.images = [ImageNodeFetch.new(common['product_photo'],
                                        "http://#{common['closeout'] ? 'outlet' : 'www'}.hitpromo.net/imageManager/show/#{common['product_photo']}")]

#        %w(imprint_colors).each do |name|
#          variations[name] ||= {}
#          value = common[name]
#          variations[name][value] = (variations[name][value] || []) + [pd.supplier_num]
#        end

        puts "Area: #{common['imprint_area']}"
        locations = parse_areas(common['imprint_area'], '•') do |locs|
          puts "LOC: #{locs.inspect}"
          locs.find_all { |s| not (/(?:See)|(?:Must)/ === s) }.join(', ')
        end
        locations.each do |imprint|
          puts "  #{imprint.inspect}"
        end

#        puts "Setup: #{common['set_up_charge']}"
        setups = []
        common['set_up_charge'].split('•').each do |str|
          str.scan(/\s*(?:([A-Z\- ]+):)?\s*\$?(\d{2,3}\.\d{2})\(G\)\s*((?:on re-orders)|(?:[,.]?\s*per\s+(?:color|side|position|panel|handle|location)|(?:1-4 Color Process)\s*)*)/i).each do |type, setup, tail|
#            puts "  #{type} : #{setup} : #{tail}"
            next if tail.downcase.include?('re-order') or (type && type.downcase.include?('re-order'))
            type = tail if tail == '1-4 Color Process'
            (type||''+' ').split(/\s+or\s+/).each do |str|
              if str.blank?
                tech = nil
              else
                unless tech = @@decoration_map[str.strip]
                  warning('Unkown Setup Technique', str.strip)
                  next
                end
              end
              if tech == 'Photo Transfer'
                setups << { :technique => tech, :fixed => 200.0, :marginal => 1.5 }
              else
                setups << { :technique => tech, :fixed => Float(setup) }
              end
            end
          end
        end if common['set_up_charge']

        case common['embroidery_information']
        when /5,000/
          setups << { :technique => 'Embroidery', :method => 'Embroidery @ 5000', :limit => 20000 }
        when /7,000/
          setups << { :technique => 'Embroidery', :method => 'Embroidery @ 7000', :limit => 20000 }
        end

#        setups.each do |imprint|
#          puts "  #{imprint.inspect}"
#        end

        limit = nil
        multi_string = common['multi_color_imprint']
        if multi_string && multi_string.downcase.include?('not available')
          limit = 1
          multi_string = nil
        end
        %w(multi_panel_imprint second_side_imprint second_handle_imprint optional_imprint).each do |name|
          break if multi_string = common[name]
        end unless multi_string

#        puts "Multi: #{multi_string}"
        running = []
        unless /^(?:(?<pre>[A-Z\- ]+):\s*)?Add (?<price>\.\d{2})\s*\(G\)\s*(?:per\s+(?:color|extra color|side|piece|position|panel|extra panel|location)[,.]?\s*)+\s*(?:\((?<limit>\d) Color Maximum\))?/ =~ multi_string
          puts "  UNKOWN: #{multi_string}" if multi_string
        else
          tech = nil
          if pre
            tech = @@decoration_map[pre.strip]
            raise "Unkown Setup Technique: #{str}" unless tech
          end
          running << { :marginal => Float(price), :limit => limit, :technique => tech }
#          setups.each do |s|
#            raise "Technique specified in setup and multi" if s[:technique] and pre
#            s.merge!(:marginal => Float(price), :limit => limit, :technique => pre)
#          end
        end

#        running.each do |imprint|
#          puts "  #{imprint.inspect}"
#        end


        techniques = []
        { 'laser' => 'Laser Engrave',
          'screen' => 'Screen Print',
          'pad' => 'Pad Print' }.each do |str, tech|
          techniques << tech if common['imprint_colors'] and common['imprint_colors'].downcase.include?(str) and !techniques.include?(tech)
        end
        pd.decorations = decorations_from_parts([locations, setups, running], techniques)

        colors = common['colors_available']
          .scan(/(?:\s*([^,:]+?)(:|(?:\s*with)))?\s*(.+?)(?:\s*(?:(?:all)|(?:both))\s*with\s*(.+?))?(?:\.|$)/i)
          .collect do |left, split, list, right|\
          
          list = list.split(/,|(?:\s+or\s+)|\|/)
          split = split.include?(':') ? ' ' : " #{split.strip} " if split
          right = " with #{right}" if right
          list.collect { |e| (right && e.include?('with')) ? e : "#{left}#{split}#{e.strip}#{right}".strip }
        end.flatten.uniq
        
        #      colors = common['colors'].split(/\s*\|\s*/).compact.collect { |c| c.split(' ').collect { |w| w.capitalize }.join(' ') }
        
        pd.variants = colors.collect do |color|
          VariantDesc.new( :supplier_num => "#{supplier_num}-#{color.gsub(' ', '')}"[0..63],
                           :properties => { 'color' => color},
                           :images => [])
        end
      end
    end

#    variations.each do |name, common|
#      puts "#{name}:"
#      common.to_a.sort_by { |k, v| k || '' }.each do |elem, list|
#        puts "  #{list.length}: #{elem.inspect}" # : #{list.join(',')}"
#      end
#    end
  end

end
