class AshCityXML < GenericImport
  def initialize(file_name)
    @src_file = File.join(JOBS_DATA_ROOT,file_name)
    super "Ash City"
  end

  def parse_products
    puts "Reading XML"  
    doc = File.open(@src_file) { |f| Nokogiri::XML(f) }
    
    products = {}

#    common = %w(StyleName StyleDesC StyleFabric Category Brand Page)
    common = %w(StyleName StyleDes StyleFabric Category Brand Page)
    unique = %w(ProductCode ColorCode ColorName SizeCode SizeName ASI ASI_1 ASI_2 NET NET_1 NET_2 HImg Weight Volume)

    doc.root.children.first.children.first.children.each do |detail|
      product_num = detail['StyleNo'].strip
      unless prod = products[product_num]
        prod = products[product_num] = common.each_with_object({}) { |c, h| h[c] = detail[c].strip if detail[c] }
      else
        common.each do |c|
          if prod[c] and detail[c]
            raise "Doesn't Match: #{c}: #{prod[c]} != #{detail[c]}" unless prod[c] == detail[c].strip
          else
            prod[c] ||= detail[c]
          end
        end
      end

      variant = unique.each_with_object({}) { |c, h| h[c] = detail[c].strip if detail[c] }

      color_codes = variant['ColorCode'].split(',')
      variants = color_codes.zip(color_codes[1..-1]).collect do |color_code, cc2|
        pre = variant['ColorName'].scan(Regexp.new("#{color_code} (.+?)" + (cc2 ? ",? ?\\*?#{cc2}" : "$")))
        if pre[0].nil? or pre[0][0].nil?
          names = variant['ColorName'].split(',')
          raise "List size doesn't match" unless color_codes.length == names.length
          puts "Color Kludge 1: #{product_num}"
          color_name = names[color_codes.index(color_code)]
          color_codes.index(color_code)
        else
          color_name = pre[0][0]
        end

        raise "Unknown Color: #{color.inspect} of #{variant['ColorName']} / #{variant['ColorCode']}" unless color_name
        
        variant['SizeName'].split(',').collect do |size|
          variant.merge('ProductCode' => detail['ProductCode'] ? detail['ProductCode'] : "#{product_num}-#{color_code}-#{size}",
                        'ColorCode' => color_code,
                        'ColorName' => color_name,
                        'SizeCode' => size,
                        'SizeName' => size,
                        'HImg' => "http://www.ashcity.com/ProductImages/Hi_res/#{product_num}_#{color_code}_H.jpg")
        end
      end.flatten

      prod['variants'] = (prod['variants'] || []) + variants
    end

    puts "Main"

    products.each do |style, src_data|    
      prod_data = {
        'supplier_num' => style,
        'material' => src_data['StyleFabric'],
        'supplier_categories' => [[src_data['Category'], src_data['Brand']]]
      }

      name = src_data['StyleName']

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
      doc = Nokogiri::HTML(src_data['StyleDes'])
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
          [['', 12], ['_1', 150], ['_2', 300]].collect do |post, min|
            return nil if (str = src[pre+post]).blank?
            { :fixed => Money.new(0),
              :minimum => min,
              :marginal => Money.new(Float(str))
            }
          end.compact
        end

        costs << { :minimum => 600 }

        {
          'supplier_num' => src['ProductCode'] || style,
          'material' => prod_data['material'],
          'images' => ImageNodeFetch.new(src['HImg'].split('/').last, src['HImg']),
          'prices' => prices,
          'costs' => costs,
          'color' => src['ColorName'].gsub(/<.+?>/, '').strip,
          'size' => src['SizeName']
          }
      end

      add_product(prod_data)
    end 
  end
end
