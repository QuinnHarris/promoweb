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
      prod_data = {
        'supplier_num' => style,
        'material' => common['Style Fabric'],
        'supplier_categories' => [[common['Category'], common['Brand']].compact],
        'images' => []
      }

      name = common['Style Name']

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
      doc = Nokogiri::HTML(common['Style Des'])
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

      prod_data['variants'] = unique.collect do |src|
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
          'images' => [ImageNodeFetch.new(src['HImg'].split('/').last, src['HImg'])],
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
