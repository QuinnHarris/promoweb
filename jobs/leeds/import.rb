# -*- coding: utf-8 -*-
class PolyXLS < GenericImport
  def initialize(name, options = {})
    @options = options
    super name
  end

  def fetch_parse?
    time = Time.now - 1.day
    fetched = false
    @prod_files = [@product_urls].flatten.collect do |url|
      wf = WebFetch.new(url)
      fetched = true if wf.fetch?(time)
      wf.get_path
    end
    wf = WebFetch.new(@decoration_url)
    fetched = true if wf.fetch?(time)
    @dec_file = wf.get_path(time)
    @src_files = @prod_files + [@dec_file]
    fetched
  end

  def parse_products
    @image_list = get_ftp_images(@image_url) do |path, file|
      if /^((?:\d+|[A-Z]{2})-\d+)([A-Z]*).*\.(?:(?:tif)|(?:jpg))$/i === file
        product, variant = $1, $2
        tag = nil
        case file
        when /^\w+_B/
          tag = 'blank'
        when /^\w+_D/
          tag = 'decorated'
        end
        
        [file, product, variant, tag]
      end
    end

    # Remove jpg if tif equivelent
    @image_list.each do |num, list|
      keeps = list.collect do |path, file, var_id|
        name, ext = file.split('.')
        ext.downcase == 'tif' ? name.downcase : nil
      end.compact
      list.delete_if do |path, file, var_id|
        name, ext = file.split('.')
        next false unless ext.downcase == 'jpg'
        keeps.include?(name.downcase)
      end
    end

    puts "Loading Decorations"
    decoration_data = {}
    decoration_data.default = []

    ws = Spreadsheet.open(@dec_file).worksheet(0)
    ws.use_header
    # supplier_num => technique => location : limit
    ws.each(1) do |row|
      @supplier_num = row['ItemNumber'].to_s.strip
      next if @supplier_num.empty?

      raise "Bad Item: #{@supplier_num}" unless /^((?:\d+|[A-Z]{2})-\d+)(\w*)/ =~ @supplier_num
      prefix = $1

      dd = DecorationDesc.new

      dd.location = row['Location'].to_s.split(' ').collect do |w| 
        %w(ON FROM BETWEEN DOWN).index(w) ? w.downcase : w.capitalize
      end.join(' ')

      technique, dd.limit = @@decoration_replace[row['Method'].to_s]
      unless technique
        warning "Unknown Decoration", row['Method'].to_s
        next
      end
      dd.technique = technique
      dd.limit = 1 if dd.location.downcase.index("one color")
      
      dd.width = row['Length']
      dd.height = row['Height']

      decoration_data[prefix] += [dd]
    end


    @prod_files.each do |file|
      ws = Spreadsheet.open(file).worksheet(0)
      ws.use_header
      ws.each(1) do |row|
        next unless row['ItemNumber']
        @supplier_num = row['ItemNumber'].strip

        ProductDesc.apply(self) do |pd|
          pd.supplier_num = @supplier_num = row['ItemNumber'].strip
          pd.name = row['ProductName']
          pd.lead_time.normal_min = 3
          pd.lead_time.normal_max = 5
          pd.lead_time.rush = 1
          pd.supplier_categories = [[row['Category'], row['SubCategory']]]
          
          pd.tags = []
          pd.tags << 'New' if row['NewItem'] == 'NEW'
          pd.tags << 'Eco' if row['Category'] == 'EcoSmart'
          
          pd.package.merge_from_object(row,
                                       { 'units' => 'CartonPackQTY',
                                         'weight' => 'CartonWeight',
                                         'width' => 'GIFTBOXED_WIDTH',
                                         'length' => 'GIFTBOXED_LENGTH',
                                         'height' => 'GIFTBOXED_Height' })
          
          pd.description = row['ItemDescription'].to_s.split(/[\r\n]+|(?:\. )\s*/).collect do |line|
            line.strip
            next nil if line.empty?
            line.scan(/\(#(.+?)\)/).flatten.each do |num|
              #          puts "MATCHING: #{num.inspect}"
              next unless product = @supplier_record.products.find_by_supplier_num(num)
              unless line.sub!("#{product.name} (##{num})", "<a href='#{product.web_id}'>#{product.name}</a>")
                line.sub!("(##{num})", "<a href='#{product.web_id}'>(M#{product.id})</a>")
              end
          end
            #        line.sub!('www.leedsworldrefill.com', "<a href='http://www.leedsworldrefill.com/'>www.leedsworldrefill.com</a>")
            [??,?!,?.].include?(line[-1]) ? line : "#{line}." 
          end.compact
          
          pricing = PricingDesc.new
          %w(First Second Third Fourth Fifth).each do |name|
            pricing.add(row["#{name}ColMinQty"], row["#{name}ColPriceUSD"])
          end
          pricing.eqp(0.4, true)
          pricing.ltm_if(40.00, 4) # LTM of 4 unless clearance
          pricing.maxqty(row['FifthColMaxQty'] && (Integer(row['FifthColMaxQty'])+1))

          
          
          dimension = {}
          { 'ItemLength'=> 'length', 
            'ItemWidth' => 'width',
            'ItemHeight' => 'height' }.each do |src, dst|
            num = row[src].to_s.gsub('\'','').to_f
            dimension[dst] = num unless num == 0.0
          end
          pd.properties['dimension'] = dimension
          
          pd.properties['material'] = row['Material'].to_s

          unless dec = decoration_data[@supplier_num]
            warning 'No Decoration'
            dec = []
          end
          pd.decorations = [DecorationDesc.none] + dec
                    
          colors = row['Color'].to_s.split(/\s*(?:(?:\,|(?:\sor\s)|(?:\sand\s)|\&)\s*)+/).uniq
          colors = [''] if colors.empty?
        
          color_image_map, color_num_map = match_colors(colors, :prune_colors => @options[:prune_colors])
          #      puts "ColorMap: #{product_data['supplier_num']} #{color_image_map.inspect} #{color_num_map.inspect}"
          pd.images = color_image_map[nil]
          
          postfixes = Set.new
          pd.variants = colors.collect do |color|
            postfix = color_num_map[color] #[@@color_map[color.downcase]].flatten.first
            unless postfix
              postfix = @@color_map[color.downcase]
              postfix = color.split(/ |\//).collect { |c| [@@color_map[c.downcase]].flatten.first }.join unless postfix
              puts "NoPost: #{@supplier_num}: #{color} : #{postfix}"
            #          postfix = color[0...8]
            end

            # Prevend duplicate postfix
            postfix += 'X' while postfixes.include?(postfix)
            postfixes << postfix

            VariantDesc.new(:supplier_num => "#{@supplier_num}#{postfix}",
                            :properties => {
                              'color' => color.strip.capitalize,
                            },
                            :pricing => pricing,
                            :images => color_image_map[color])
          end
        end
      end
    end
  end

  cattr_reader :color_map
  @@color_map =
  { '' => '',
    'limeágreen' => 'LGR', #Kludge for SM-3235
    'processáblue' => 'NEBL',
    'amthyst' => 'AM',
    'aquarium' => 'BK',
    'bk on bk' => 'RBB',
    'black' => 'BK',
    'black top with clear base' => 'BK',
    'black with silver trim' => 'SIBK', # KK-640
    'black/red' => 'BKR',
    'black pin stripe' => 'BKP', # 2050-14
    'blue' => 'BL',
    'blue/black' => 'BLBK',
    'blue with silver trim' => 'SBL', # KK-640
    'brown' => 'BR',
    'burgundy' => 'BU',
    'camouflage' => 'CA',
    'component' => 'CM', # 1030-49
    'copper' => 'CO',
    'charcoal' => 'CH',
    'chestnut' => 'CT',
    'clear' => 'CL',
    'cream' => 'CR',
    'dark red' => 'RE',
    'emerald' => 'EM',
    'espresso' => 'ES',
    'frosted orange' => 'FOR',
    'frosted red' => 'FRE',
    'gold' => 'GL',
    'graphite' => 'GA',
    'gray' => 'GY',
    'gray granite' => 'GG',
    'green' => 'GR',
    'dark green' => 'DGR',
    'green with silver trim' => 'SIGR', # KK-640
    'kelly green' => 'KGR', # SM-3122
    'grey' => 'GY',
    'gunmetal' => 'GM',
    'hunter green' => 'HG',
    'iron' => 'IN',
    'light blue' => ['LBL', 'LB'],
    'lime' => 'LM',
    'lime green' => 'LGR',
    'mahogany' => 'CC',
    'mahogny' => 'CC',
    'maroon' => 'MA',
    'matte silver' => 'SI',
    'midnight chrome' => 'SL',
    'multicol' => 'MT',
    'multicolor' => 'MT',
    'natural' => 'NT',
    'navy' => 'NY',
    'navy blue' => 'NBL',
    'neon green' => 'NG',
    'ni' => 'NI',
    'olive' => 'OL',
    'orange' => 'OR',
    'pearlescent neon orange' => 'NOR', # KK-640
    'pearlescent neon yellow' => 'NY', # KK-640
    'pearlescent neon green' => 'NG', # KK-640
    'pearlescent neon pink' => 'NP', # KK-640
    'pink' => 'PK',
    'plasma ball' => 'BB',
    'poncho' => 'WH',
    'purple' => 'PP',
    'quartz' => 'QZ',
    'red' => ['RE', 'RD'],
    'red with silver trim' => 'SIRE', # KK-640
    'reflective triangle' => 'RE',
    'reflex blue' => 'REBL',
    'royal' => 'RY',
    'royal blue' => 'RBL',
    'ruby' => 'RU',
    'rust' => 'RS',
    'sapphire' => 'SA',
    'silver' => ['SI', 'S'],
    'silver barrel' => 'SI',
    'silver with black trim' => 'SIBK',
    'silver with black grip' => 'SIBK', # KK-930
    'silver with blue trim' => 'SIBL',
    'silver with green trim' => 'SIGR',
    'silver with red trim' => 'SIRE',
    'silver with frosted black grip' => 'SBK',
    'silver with frosted blue grip' => 'SBL',
    'silver with frosted green grip' => 'SGR',
    'silver with frosted orange grip' => 'SOR',
    'silver with frosted red grip' => 'SRE',
    'silver with green grip' => 'SGR',
    'silver with black lower barrel' => 'SIBK', # KK-955
    'silver with blue lower barrel' => 'SIBL', # KK-955
    'silver with red strap' => 'RE',
    'silver/black' => 'SIBK',
    'silver/blue' => 'SIBL',
    'silver/green' => 'SIGR',
    'silver/red' => 'SIRE',
    'smoke' => 'SM',
    'stainless steel' => 'SS',
    'strawberry granite' => 'SG',
    'solid blue' => 'SBL',
    'solid black' => 'SBK', # KK-640
    'taupe' => 'TP',
    'teal' => 'TE',
    'titanium' => 'TI',
    'translucent black' => 'TBK',
    'translucent blue' => 'TBL',
    'translucent green' => 'TGR',
    'translucent light blue' => 'TLBL',
    'translucent orange' => 'TOR',
    'translucent pink' => 'TPK',
    'translucent purple' => 'TPR',
    'translucent purple' => 'TPU',
    'translucent red' => 'TRE',
    'translucent royal blue' => 'TRBL',
    'translucent yellow' => 'TYE',
    'transparent aqua blue' => 'TABL',
    'transparent black' => 'TBK',
    'transparent blue' => 'TBL',
    'transparent blue top/base' => 'TLB',
    'transparent dark blue' => 'TDBL',
    'transparent green' => 'TGR',
    'transparent green top/base' => 'TGR',
    'transparent orange' => 'TOR',
    'transparent pink' => 'TPK',
    'transparent purple' => 'TPU',
    'transparent red' => 'TRE',
    'transparent yellow' => 'TYE',
    'turquoise' => 'TQ',
    'white' => 'WH',
    'white barrel' => 'W',
    'white top with clear base' => 'WH',
    'white with black' => 'WH-BK',
    'white with black trim' => 'WBK', # KK-640
    'white with green trim' => 'WGR', # KK-640
    'white with red trim' => 'WRE', # KK-640
    'white with blue trim' => 'WBL', # KK-640
    'white with orange trim' => 'WOR', # KK-640
    'white with yellow trim' => 'WYE', # KK-640
    'white with blue' => 'WH-BL',
    'white with green' => 'WH-GR',
    'white with translucent red trim' => 'WRE',
    'white/blue' => 'WBL',
    'white/red' => 'WRE',
    'wood' => 'WD',
    'yellow' => ['YE', 'YW'],
  }

  # Decoration XLS file
  @@decoration_replace = {
    'Silkscreen' => ['Screen Print',3],
    'ColorPrint' => ['Screen Print',3],
    'Drinkware' => ['Screen Print',3],
    'Transfer' => ['Screen Print',3],
    'Watch Printing' => ['Screen Print', 3],

    'PhotoReal' => ['Photo Transfer',3],
    'Photografixx' => ['Photo Transfer',1],
    'Deboss' => ['Deboss',1],
    'Deboss Initials' => nil,
    'Laser Etching' => ['Laser Engrave',1],
    'Laser Etching Name' => [nil,1],
    'Laser Etching Initials' => [nil,1],
    'Laser Etch With Outline' => [nil,1],
    'Laser Outline Only' => [nil,1],
    'Name- personalization' => [nil,1],

    'Embroidery' => ['Embroidery', 10000],
    'Embroidery Initials' => nil,
    'Embroidery Name' => nil,

    'Custom Dome' => nil,
    'Epoxy Dome' => ['Dome', 1],
    'Epoxy Dome Pers' => nil,

    'Color Fill' => nil,
    'Color Fill Initials' => nil,

    'Color Stamp' => ['Stamp', 1],
    'Color Stamp DB' => ['Stamp', 1],
    'Color Stamp Name' => nil,
    'Color Stamp Initials' => nil,

    'Oxidize' => nil,

    'Sticker' => nil,

    'Upload' => nil,

    'Metal' => nil,

    '3d' => nil,

    
    # Bullet
    'Silkscreened' => ['Screen Print',3],
    'Silskcreened' => ['Screen Print',3],
    'Laser Engraved' => ['Laser Engrave',1],
    'Engraving' => ['Laser Engrave',1],
    'Engraved' => ['Laser Engrave',1],
  }
end
