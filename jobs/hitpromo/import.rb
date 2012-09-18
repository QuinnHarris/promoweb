# -*- coding: utf-8 -*-
require 'csv'

class HitPromoCSV < GenericImport  

  def initialize(year)
    puts "Starting Fetch for #{year}"
    @src_file = WebFetch.new("http://www.hitpromo.net/fs/documents/hit_product_data_#{year}.csv").get_path(Time.now - 1.day)
    super 'Hit Promotional Products'

    @decoration_set = Set.new
#    @decoration_set += @supplier_record.decoration_price_groups.all.collect(&:name)
  end

  def get_decoration(technique, fixed, marginal)
    fixed = Money.new(fixed)
    name = "#{technique} @ #{fixed}"
    marginal = Money.new(marginal) if marginal
    name += "/#{marginal}" if marginal
    path = [technique, name]
    return path if @decoration_set.include?(path)
    
    base_tech = DecorationTechnique.find_by_name(technique)
    raise "Unkown Technique: #{technique}" unless base_tech
    unless tech = base_tech.children.find_by_name(name)
      DecorationTechnique.transaction do
        tech = base_tech.children.create(:name => name, :unit_name => base_tech.unit_name,
                                         :unit_default => base_tech.unit_default)
        price_group = tech.price_groups.create(:supplier => @supplier_record)
        price_group.entries.create(:minimum => 1,
                                   :fixed_price_const => 0.0,
                                   :fixed_price_exp => 0.0,
                                   :fixed_price_marginal => Money.new(0),
                                   :fixed_price_fixed => fixed,
                                   :fixed => PriceGroup.create_prices([
                                   {  :fixed => (fixed*0.8).round_cents,
                                      :marginal => Money.new(0), :minimum => 1 }]),
                                   :marginal_price_const => 0.0,
                                   :marginal_price_exp => 0.0,
                                   :marginal_price_marginal => marginal || Money.new(0),
                                   :marginal_price_fixed => fixed,
                                   :marginal => PriceGroup.create_prices([
                                   {  :fixed => (fixed*0.8).round_cents,
                                      :marginal => marginal ? (marginal*0.8).round_cents : Money.new(0), :minimum => 1 }]),
                                   )

        DecorationDesc.techniques[path] = tech
      end
    end
    @decoration_set << path
path
  end

#%w(colors_available imprint_colors approximate_size imprint_area set_up_charge multi_color_imprint packaging multi_panel_imprint second_side_imprint fob_zip second_handle_imprint please_note embroidery_information thread_colors tape_charge sizes approximate_bag_size optional_imprint second_positon non_woven_items label_color four_color_process optional_imprint_area second_position_imprint highlighters imprint catalog_page colors)

  @@decoration_hash = {
    'Debossed' => 'Deboss',
    'Embroidered' => 'Embroidery',
    'Embroidery' => 'Embroidery',
    'Laser Engrave' => 'Laser Engrave',
    'Laser Engraved' => 'Laser Engrave',
    'Laser Engraving' => 'Laser Engrave',
    'Optional Embroidered' => 'Embroidery',
    'Oval' => 'Dome',
    'Oval Dome' => 'Dome',
    'Pad-Print' => 'Pad Print',
    'Silk-Screen' => 'Screen Print',
    'Silk-Screen or Transfer' => ['Screen Print', 'Photo Transfer'],
    'Silk-Screened' => 'Screen Print',
    'Transfer' => 'Photo Transfer'
  }
 
  def parse_products
    common_list = %w(product_name new description category product_photo colors_available imprint_colors approximate_size imprint_area set_up_charge multi_color_imprint packaging multi_panel_imprint second_side_imprint fob_zip second_handle_imprint please_note embroidery_information thread_colors tape_charge sizes approximate_bag_size optional_imprint precious_metal_imprint for_gold_banding for_halo battery second_positon non_woven_items label_color four_color_process optional_imprint_area second_position_imprint highlighters refills optional_carabiner imprint catalog_page optional_pen colors)

    price_list = %w(discount_code) + (1..8).collect { |n| ["price#{n}", "quantity#{n}"] }.flatten

    product_list = {}
    CSV.foreach(@src_file, :headers => :first_row, :col_sep => ' ', :quote_char => "'") do |row|
      unless /^(.+?)([BELST])?$/ === row['product_sku']
        raise "Bad Reg"
      end
      supplier_num = $1
      postfix = $2

      if hash = product_list[supplier_num]
        common_list.each do |name|
          raise "Mismatch: #{supplier_num} #{name} #{hash[name]} != #{row[name]}" unless hash[name] == ((row[name] == '--') ? nil : row[name])
        end
        price_hash = hash['price']
        puts "Duplicate Price: #{supplier_num} #{price_hash.inspect}" if price_hash[postfix]
      else
        hash = product_list[supplier_num] = common_list.each_with_object({}) do |name, hash|
          hash[name] = row[name] unless row[name] == '--'
        end
        price_hash = {}
      end

      price_hash[postfix] = price_list.each_with_object({}) do |name, hash|
        hash[name] = row[name]
      end
      hash['price'] = price_hash
    end

    puts "Len: #{product_list.length}"

    price_preference = %w(L S T E B)
    
    variations = {}

    product_list.each do |supplier_num, hash|
      ProductDesc.apply(self) do |pd|
        pd.supplier_num = supplier_num
        pd.name = hash['product_name']
        pd.supplier_categories = [[hash['category'].strip]]
        pd.tags = []

        pd.description = hash['description'] ? hash['description'].split(/\s*\|\s*/).join("\n") : ''
        pd.description += hash['please_note'].gsub(/\s*((<.+?>)|[^[[:ascii:]]])\s*/,' ').split(/\s*\n\s*/).join("\n") if hash['please_note']

        %w(precious_metal_imprint for_gold_banding for_halo refills optional_carabiner optional_pen battery).each do |name|
          next unless hash[name]
          str = "\n" + name.split('_').collect { |w| w.capitalize }.join(' ') + ": "
          str << hash[name].gsub(/<a href=".+?">(\d+)<\/a>/) do |str|
            product = get_product($1)
            "<a href='#{product.web_id}'>#{product.name}</a>"
          end
          pd.description += str
        end
        
        pd.tags << 'New' if hash['new']

      # Packaging
#      unless /(\d+) per carton.+?(\d+) lbs/ === hash['packaging']
#        raise "Unknown Packaging: #{hash['packaging'].inspect}"
#      end
#      product_data.merge!('package_units' => Integer($1),
#                          'package_weight' => Integer($2))


        # Prices
        price_string = hash['price'][hash['price'].keys.sort_by { |s| price_preference.index(s) }.first]
        pricing = PricingDesc.new
        discounts = convert_pricecodes(price_string['discount_code'])
        (1..8).each do |i|
          qty = price_string["quantity#{i}"]
          break if qty.blank?
          unless discounts.first
            puts "Extra Column: #{supplier_num}"
            break
          end
          
          pricing.add(qty, price_string["price#{i}"], discounts.shift)
        end
        raise "Discount doesn't match: #{supplier_num} #{discounts.inspect}" unless discounts.empty?
        pricing.maxqty

        dimension = hash['approximate_size'] || hash['approximate_bag_size']
        pd.properties['dimension'] = parse_volume(dimension) if dimension


        pd.images = [ImageNodeFetch.new(hash['product_photo'],
                                        "http://www.hitpromo.net/imageManager/show/#{hash['product_photo']}")]

        %w(multi_color_imprint multi_panel_imprint second_side_imprint second_handle_imprint).each do |name|
          variations[name] ||= {}
          value = hash[name]
          variations[name][value] = (variations[name][value] || []) + [pd.supplier_num]
        end

        puts
        puts "Area: #{hash['imprint_area']}"
        locations = []
        hash['imprint_area'].gsub(' ',' ').split('•').each do |str|
          str.scan(/\s*(?:([A-Z\- ]+):)?\s*(?:([A-Z\- ]+):)?\s*(?:\((.+?)\):?)?\s*((?:[^A-Z]+W\s*x\s*[^A-Z]+?H)|(?:[^A-Z]+(?:Diameter|Square)))\s*(?:\((.+?)\))?/i).each do |a, b, c, dim, d|
            loc = [a, b, c, d].compact
            decoration = nil
            loc.delete_if do |str|
              if dec = @@decoration_hash[str.strip]
                raise "Duplicate decoration" if decoration
                decoration = dec
              end
            end
#            decoration ||= 'Screen Print'
            if area = parse_area_new(dim)
              locations += [decoration].flatten.collect do |dec|
                { :technique => dec, :location => loc.join(', ') }.merge(area)
              end
            else
              warning supplier_num, "Unkown Decoration", "#{decoration.inspect}: #{area.inspect} (#{loc.join(', ')}) [#{dim.inspect} #{a.inspect} #{b.inspect} #{c.inspect}]"
            end
          end
        end if hash['imprint_area']

        locations.each do |imprint|
          puts "  #{imprint.inspect}"
        end

        puts "Setup: #{hash['set_up_charge']}"
        setups = []
        hash['set_up_charge'].split('•').each do |str|
          str.scan(/\s*(?:([A-Z\- ]+):)?\s*\$?(\d{2,3}\.\d{2})\(G\)\s*((?:on re-orders)|(?:[,.]?\s*per\s+(?:color|side|position|panel|handle|location)\s*)*)/i).each do |type, setup, tail|
            puts "  #{type} : #{setup} : #{tail}"
            next if tail.downcase.include?('re-order') or (type && type.downcase.include?('re-order'))
            (type||''+' ').split('or').each do |str|
              if str.blank?
                tech = nil
              else
                unless tech = @@decoration_hash[str.strip]
                  warning(pd.supplier_num, 'Unkown Setup Technique', str.strip)
                  next
                end
              end
              setups << { :technique => tech, :fixed => Float(setup) }
            end
          end
        end if hash['set_up_charge']

        setups.each do |imprint|
          puts "  #{imprint.inspect}"
        end

        limit = nil
        multi_string = hash['multi_color_imprint']
        if multi_string && multi_string.downcase.include?('not available')
          limit = 1
          multi_string = nil
        end
        %w(multi_panel_imprint second_side_imprint second_handle_imprint).each do |name|
          break if multi_string = hash[name]
        end

        puts "Multi: #{multi_string}"
        running = []
        unless /^(?:(?<pre>[A-Z\- ]+):\s*)?Add (?<price>\.\d{2})\s*\(G\)\s*(?:per\s+(?:color|extra color|side|piece|position|panel|extra panel|location)[,.]?\s*)+\s*(?:\((?<limit>\d) Color Maximum\))?/ =~ multi_string
          puts "  UNKOWN" if multi_string
        else
          tech = nil
          if pre
            tech = @@decoration_hash[pre.strip]
            raise "Unkown Setup Technique: #{str}" unless tech
          end
          running << { :marginal => Float(price), :limit => limit, :technique => tech }
#          setups.each do |s|
#            raise "Technique specified in setup and multi" if s[:technique] and pre
#            s.merge!(:marginal => Float(price), :limit => limit, :technique => pre)
#          end
        end

        running.each do |imprint|
          puts "  #{imprint.inspect}"
        end

        pd.decorations = [DecorationDesc.none]

        combos = [locations, setups, running]
        techniques = (locations + setups + running).collect { |e| e[:technique] }.compact.uniq
        techniques << "Screen Print" if techniques.empty?
        techniques.each do |tech|
          subs = combos.collect do |set|
            r = set.find_all { |l| l[:technique].nil? || l[:technique] == tech }
            r.empty? ? [{}] : r
          end

          def decend(hash, subs, tech)
            if subs.empty?
              return unless fixed = hash.delete(:fixed)
              marginal = hash.delete(:marginal)
              dec = get_decoration(tech, fixed, marginal)
              hash = hash.merge(:technique => dec)
              puts "  DecDesc: #{hash.inspect}"
              DecorationDesc.new(hash)
            else
              subs.first.collect do |sub|
                decend(hash.merge(sub), subs[1..-1], tech)
              end
            end
          end
          
          pd.decorations += decend({}, subs, tech).flatten.compact
        end


        colors = hash['colors_available']
          .scan(/(?:\s*([^,:]+?)(:|(?:\s*with)))?\s*(.+?)(?:\s*(?:(?:all)|(?:both))\s*with\s*(.+?))?(?:\.|$)/)
          .collect do |left, split, list, right|\
          
          list = list.split(/,|(?:\s+or\s+)/)
          split = split.include?(':') ? ' ' : " #{split.strip} " if split
          right = " with #{right}" if right
          list.collect { |e| (right && e.include?('with')) ? e : "#{left}#{split}#{e.strip}#{right}".strip }
        end.flatten.uniq
        
        #      colors = hash['colors'].split(/\s*\|\s*/).compact.collect { |c| c.split(' ').collect { |w| w.capitalize }.join(' ') }
        
        pd.variants = colors.collect do |color|
          VariantDesc.new( :supplier_num => "#{supplier_num}-#{color.gsub(' ', '')}"[0..63],
                           :pricing => pricing, :properties => { 'color' => color},
                           :images => [])
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
