require 'csv'

class AshCityXLS < GenericImport
  def initialize(files)
    @src_files = [files].flatten.collect { |f| File.join(JOBS_DATA_ROOT, "AshCity/#{f}") }
    super "Ash City"
  end

  def process_row(product_merge, row)
    return unless row['Style No'] # Why is this needed?

    product_num = row['Style No'].strip
    unique = product_merge.merge(product_num, row)   

    if row.header?('Color Codes')
      color_codes = row['Color Codes'].split(',')
      
      variants = color_codes.zip(color_codes[1..-1]).collect do |color_code, cc2|
        pre = unique['Color Name'].scan(Regexp.new("#{color_code} (.+?)" + (cc2 ? ",? ?\\*?#{cc2}" : "$")))
        if pre[0].nil? or pre[0][0].nil?
          names = unique['Color Name'].split(',')
          raise "List size doesn't match" unless color_codes.length == names.length
          puts "Color Kludge 1: #{product_num}"
          color_name = names[color_codes.index(color_code)]
          color_codes.index(color_code)
        else
          color_name = pre[0][0]
        end
        
        raise "Unknown Color: #{color.inspect} of #{variant['ColorName']} / #{variant['ColorCode']}" unless color_name
        
        unique['Size Name'].split(',').collect do |size|
          unique.merge!('Product Code' => row['Product Code'] || "#{product_num}-#{color_code}-#{size}",
                        'Color Code' => color_code,
                        'Color Name' => color_name,
                        'Size Code' => size,
                        'Size Name' => size,
                        'HImg' => "http://www.ashcity.com/ProductImages/Hi_res/#{product_num}_#{color_code}_H.jpg")
        end
      end
    end
  end

  def parse_products
    common = %w(Style\ Name Style\ Des Style\ Fabric Category Brand Page)
    unique = %w(Product\ Code Color\ Code Color\ Name Size\ Code Size\ Name HImg Weight Volume) + %w(1st 2nd 3rd).collect { |str| ["US ASI #{str}", "US NET #{str}"] }.flatten
    product_merge = ProductRecordMerge.new(unique, common)

    @src_files.each do |file|
      if file.include?(".csv")
        puts "Reading CSV: #{file}"
        CSV.foreach(file, :headers => :first_row) do |row|
          process_row product_merge, row
        end
      else
        puts "Reading Excel: #{file}"
        ws = Spreadsheet.open(file).worksheet(0)
        ws.use_header(3)
        ws.each(4) do |row|
          process_row product_merge, row
        end
      end
    end

    product_merge.each do |style, unique, common|
      ProductDesc.apply(self) do |pd|
        pd.supplier_num = style
        pd.supplier_categories = [[common['Category'], common['Brand']].compact]
        pd.images = []
        
        
        # Name
        pd.name = common['Style Name'].gsub(/<\/?p>/, '').gsub('&nbsp;', ' ').strip
        if pd.name.gsub!(/(?<tag><(?:strong|span)[^>]*>\s*(?:\g<tag>*|new)\s*<[^>]+>)\s*/i, '')
          pd.tags << 'New'
        end
        pd.tags << 'Eco' if pd.name.include?('e.c.o')
        # De capitalize
        down_words = %w(and in with)
        pd.name = pd.name.scan(/(.+?)(\s+|-|\/|(?:<.+?>)|$)/).collect do |str, gap|
          [down_words.include?(str.downcase) ? str.downcase : str.capitalize, gap]
        end.flatten.join
        
        # Description
        doc = Nokogiri::HTML(common['Style Des'])
        pd.description = doc.root.search('ul/li').collect { |n| n.text.gsub(/\s+/, ' ').strip }

        # Fabric
        if common['Style Fabric'].include?('<ul>')
          doc = Nokogiri::HTML(common['Style Fabric'])
          list = doc.root.search('ul/li').collect { |n| n.text.gsub(/\s+/, ' ').strip }
          pd.description += "\n" + list.join("\n")
          pd.properties['material'] = list.first
        elsif common['Style Fabric'].include?('br>')
          list = common['Style Fabric'].split(/<\/?br>/).collect { |s| s.gsub(/\s+/, ' ').strip }
          pd.description += "\n" + list.join("\n")
          pd.properties['material'] = list.first
        else
          pd.properties['material'] = common['Style Fabric'].gsub(/<\/?p>/, '').strip
        end
        
        # Decorations
        pd.decorations = [DecorationDesc.none,
                          DecorationDesc.new(:technique => 'Heat Transfer',
                                             :location => '', :limit => 20),
                          DecorationDesc.new(:technique => 'Embroidery',
                                             :location => '', :limit => 25000) ]
        
        pd.lead_time.normal_min = 5
        pd.lead_time.normal_max = 7
        
        pd.variants = unique.collect do |src|
          vd = VariantDesc.new(:supplier_num => src['Product Code'] || style,
                               :images => src['HImg'].downcase.include?('jpg') ? [ImageNodeFetch.new(src['HImg'].split('/').last, src['HImg'])] : [],
                               :properties => {
                                 'color' => src['Color Name'].gsub(/\*?<.+?>.+?<\/.+?>/, '').strip,
                                 'size' => src['Size Name']
                               })
          
          [['1st', 12], ['2nd', 150], ['3rd', 300]].each do |num, min|
            vd.pricing.add(min, src["US ASI #{num}"], src["US NET #{num}"])
          end
          vd.pricing.maxqty
          vd
        end
      end
    end 
  end
end
