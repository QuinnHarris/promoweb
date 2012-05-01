class AshCityXLS < GenericImport
  def initialize(files)
    @src_files = files.collect { |f| File.join(JOBS_DATA_ROOT, "AshCity/#{f}") }
    super "Ash City"
  end

  def process_excel(file)
    puts "Reading Excel: #{file}"
    ws = Spreadsheet.open(file).worksheet(0)
    ws.use_header(3)

    common = %w(Style\ Name Style\ Desc Style\ Fabric Category Brand Page)
    unique = %w(Product\ Code Color\ Code Color\ Name Size\ Code Size\ Name HImg Weight Volume) + %w(1st 2nd 3rd).collect { |str| ["US ASI #{str}", "US NET #{str}"] }.flatten

    ws.each(4) do |detail|
      next unless detail['Style No'] # Why is this needed?

      product_num = detail['Style No'].strip
      unless prod = @products[product_num]
        prod = @products[product_num] = common.each_with_object({}) { |c, h| h[c] = detail[c].strip if detail[c] }
      else
        common.each do |c|
          if prod[c] and detail[c]
            raise "Doesn't Match: #{c}: #{prod[c]} != #{detail[c]}" unless prod[c] == detail[c].strip
          else
            prod[c] ||= detail[c]
          end
        end
      end


      variant = unique.each_with_object({}) { |c, h| h[c] = detail[c].is_a?(String) ? detail[c].strip : detail[c] if detail[c] }
#      puts "Variant: #{variant.inspect}"

      if ws.header_map['Color Codes']
        color_codes = detail['Color Codes'].split(',')

        variants = color_codes.zip(color_codes[1..-1]).collect do |color_code, cc2|
          pre = variant['Color Name'].scan(Regexp.new("#{color_code} (.+?)" + (cc2 ? ",? ?\\*?#{cc2}" : "$")))
          if pre[0].nil? or pre[0][0].nil?
            names = variant['Color Name'].split(',')
            raise "List size doesn't match" unless color_codes.length == names.length
            puts "Color Kludge 1: #{product_num}"
            color_name = names[color_codes.index(color_code)]
            color_codes.index(color_code)
          else
            color_name = pre[0][0]
          end
          
          raise "Unknown Color: #{color.inspect} of #{variant['ColorName']} / #{variant['ColorCode']}" unless color_name
          
          variant['Size Name'].split(',').collect do |size|
            variant.merge('Product Code' => detail['Product Code'] || "#{product_num}-#{color_code}-#{size}",
                          'Color Code' => color_code,
                          'Color Name' => color_name,
                          'Size Code' => size,
                          'Size Name' => size,
                          'HImg' => "http://www.ashcity.com/ProductImages/Hi_res/#{product_num}_#{color_code}_H.jpg")
          end
        end.flatten
      else # Just One Color Code
        variants = [variant]
      end
      
      prod['variants'] = (prod['variants'] || []) + variants
    end
  end

  def parse_products
    @products = {}

    @src_files.each { |f| process_excel(f) }  

    puts "Main: #{@products.length}"

    @products.each do |style, src_data|
      prod_data = {
        'supplier_num' => style,
        'material' => src_data['Style Fabric'],
        'supplier_categories' => [[src_data['Category'], src_data['Brand']]]
      }

      name = src_data['Style Name']

      if (wo_name = name.gsub(/<b>new<\/b>\s+/i, '')) != name
        name = wo_name
        prod_data['tags'] = ['New']
      end
      
      # De capitalize
      down_words = %w(and in with)
      name = name.scan(/(.+?)(\s+|-|\/|(?:<.+?>)|$)/).collect do |str, gap|
        [down_words.include?(str.downcase) ? str.downcase : str.capitalize, gap]
      end.flatten.join
      prod_data['name'] = name

      # Description
      doc = Nokogiri::HTML(src_data['Style Desc'])
      prod_data['description'] = doc.root.search('ul/li').collect { |n| n.text.gsub(/\s+/, ' ') }.join("\n")

      # Decorations
      list = [{
                'technique' => 'None',
                'location' => ''
              },
              {
                'technique' => 'Heat Transfer (area)',
                'location' => '',
                'limit' => 20,
              },
              {
                'technique' => 'Embroidery',
                'location' => '',
                'limit' => 25000,
              },
             ]
      prod_data['decorations'] = list

      prod_data['variants'] = src_data['variants'].collect do |src|
#        puts "Src: #{src.inspect}"
        prices, costs = %w(ASI NET).collect do |pre|
          [["US #{pre} 1st", 12], ["US #{pre} 2nd", 150], ["US #{pre} 3rd", 300]].collect do |head, min|
#           raise "no header #{head} in #{src.inspect}" if (str = src[head]).blank?
            { :fixed => Money.new(0),
              :minimum => min,
              :marginal => Money.new(Float(src[head] || 0.0))
            }
          end.compact
        end

        costs << { :minimum => 600 }

        {
          'supplier_num' => src['Product Code'] || style,
          'material' => prod_data['material'],
          'images' => ImageNodeFetch.new(src['HImg'].split('/').last, src['HImg']),
          'prices' => prices,
          'costs' => costs,
          'color' => src['Color Name'].gsub(/\*?<.+?>.+?<\/.+?>/, '').strip,
          'size' => src['Size Name']
          }
      end

      add_product(prod_data)
    end 
  end
end
