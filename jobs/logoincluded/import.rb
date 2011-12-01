require 'net/ftp'

class LogoIncludedXML < GenericImport
  def initialize
    file_name = "LogoIncluded.xml"
    @src_file = File.join(JOBS_DATA_ROOT,file_name)
    super "LogoIncluded"
  end

  def fetch
    puts "Fetching"
    remote_file = 'feed.xml'
    Net::FTP.open('ftp.logoincluded.com') do |ftp|
      ftp.login('mountainofpromos', 'Br3S9Ebr')
      if File.exists?(@src_file) and (ftp.mtime(remote_file) < File.mtime(@src_file))
        puts "** No update **"
        return
      end
      ftp.getbinaryfile(remote_file, @src_file)
    end
    puts "Fetched"
  end

  def warning(msg)
    puts "#{@product_id} - #{msg}"
  end

  def parse_products
    puts "Reading XML"
    doc = File.open(@src_file) { |f| Nokogiri::XML(f) }
    
    doc.xpath('/ProductList/Product').each do |product|
      # Product Record
      @product_id = "#{product.at_xpath('SKU').text} #{product.at_xpath('Name').text}"

      category = product.at_xpath('Category').text
      if %w(USB\ Accessories).include?(category)
        name = product.at_xpath('Name').text
      else
        name = (product.at_xpath('Name').text.split(' ')+category.split(' ')).reverse.uniq.reverse.join(' ')
      end
      product_data = {
        'supplier_num' => product.at_xpath('SKU').text,
        'name' => name,
        'supplier_categories' => [[category]],
        'description' => product.at_xpath('Description').text.gsub(/\.\s+/,".\n"),
        'data' => { :url => product.at_xpath('LogoincludedURL').text.strip }
      }

      url_string = product.at_xpath('LogoincludedURL').text.strip
      unless url_string.empty?
        unless /^http:\/\/www\.logoincluded\.com\/products\/(.+)$/ === url_string
          raise "Unknown URL: #{url_string}"
        end
        product_data['data'] = { :path => $1 }
      end
        


#      puts "Product: #{product_data['supplier_num']} : #{product_data['name']}"

      begin # Shipping
        ship_indiv = product.at_xpath('ShippingInfo/IndividualWeight').text
#        raise "unit not g: #{ship_indiv.attributes.inspect}" unless ship_indiv.attributes['unit'] != 'g'
        ship_unit = product.at_xpath('ShippingInfo/MasterCartonWeight').text
#        raise "unit not lbs" unless ship_unit.attributes['unit'] != 'lbs'
        master_qty = product.at_xpath('ShippingInfo/MasterCartonQty').text
        if master_qty.empty?
          warning "Empty Master Carton"
          master_qty = nil 
        end
        warning "Invalid MasterCartonQty: #{master_qty}" if master_qty.to_i.to_s != master_qty
        product_data.merge!({ 'package_unit_weight' => (ship_indiv && !ship_indiv.empty?) ? (Float(ship_indiv) * 0.00220462262) : nil,
                              'package_units' => master_qty && master_qty.to_i,
                              'package_weight' => (ship_unit && !ship_unit.empty?) ? Float(ship_unit) : nil })
      end

      begin # Lead Times
        production_time_reg = /(\d+)(?:-(\d+))? days?/
        std_time = product.at_xpath('ProductionTimes/StandardProductionTime').text
        unless std_time.blank?
          case std_time
          when /(\d+)(?:-(\d+))?(?: +business)? +days/i
            product_data.merge!({ 'lead_time_normal_min' => Integer($1),
                                  'lead_time_normal_max' => Integer($2 || $1) })
          when /(\d+) weeks/
            product_data.merge!({ 'lead_time_normal_min' => Integer($1)*5,
                                  'lead_time_normal_max' => Integer($1)*5 })
          else
            raise "Unknown std time: #{std_time.inspect}" unless production_time_reg === std_time
          end
        else
          warning "Unspecified Lead Time"
        end
        
        rush_time = product.at_xpath('ProductionTimes/RushProductionTime').text
        unless rush_time.blank? or (rush_time.strip == 'None')
          if production_time_reg === rush_time
            product_data.merge!({ 'lead_time_rush' => Integer($1) })
          else
            warning "Unknown rush time: #{rush_time.inspect}" 
          end
        end
      end
        
      begin # Decorations
        list = [{
          'technique' => 'None',
          'location' => ''
        }]

        list += product.xpath('ImprintArea/Location').collect do |location|
          data = {
            'technique' => 'Screen Print',
            'limit' => 5,
            'location' => location.at_xpath('Description').text }

          { 'Length' => 'width',
            'Height' => 'height' }.each do |tag, attr|
            node = location.at_xpath(tag)
            raise "Unknown #{tag} unit" unless node['unit'] == 'mm'
            data[attr] = (Float(node.text) * 3.93700787).round / 100.0
          end

          data
        end
        product_data['decorations'] = list
      end

      begin # Product Image
        image_url = product.at_xpath('Image/Large').text
        unless image_url.blank?
          product_data['image-large'] = CopyImageFetch.new(image_url)
          %w(thumb main).each do |name|
            product_data["image-#{name}"] = TransformImageFetch.new(image_url)
          end
        else
          warning "Unspecified image"
          next
        end
      end
 
      colors = product.xpath('ColorOptions/Color/Description').collect { |n| n.text }.uniq

      nums = []
      min_units = 10000000
      max_units = 0

      product_data['variants'] = product.xpath('Pricing/LineItem').collect do |li|
        last_maximum = nil
        prices = li.xpath('UnitPriceBreaks/Quantity').collect do |qty|
          min, max = %w(minimum maximum).collect { |n| qty[n].blank? ? nil : Integer(qty[n]) }
          if min and max and max < min
            puts "EXCLUDING: #{max} < #{min}"
            next
          end
          min_units = [min_units, max].min
          max_units = [max_units, max].max
#          puts "Min: #{min} #{max}"
#          raise "Non sequential quantity" if last_maximum and (last_maximum == min - 1)
          last_maximum = max
          price = Money.new(Float(qty.at_xpath('Price').text))
          next nil if price.zero?
          { :fixed => Money.new(0.0),
            :marginal => price,
            :minimum => max
          }
        end.compact
        # Less than MINIMUM !!!!! ?????

        costs = []
        if prices.empty?
          warning "No Prices"
        else
          # EQP
          costs = [{ :fixed => Money.new(0),
                     :marginal => prices.first[:marginal],
                     :minimum => prices.first[:minimum] }]

          costs << { :fixed => Money.new(0),
                     :marginal => prices.last[:marginal],
                     :minimum => prices[1][:minimum] } if prices.length > 1

          costs << { :minimum => prices.last[:minimum] * 2 }

          prices.each do |p|
            p[:marginal] = (p[:marginal] / 0.6).round_cents;
          end
        end

        data = { 'prices' => prices, 'costs' => costs }

        description = li['description']
        case description
          when /(\d+(?:(?:MB)|(?:GB?))) USB 2.0/
          data['memory'] = $1
          data['supplier_num'] = "#{product_data['supplier_num']}-#{$1}"
        else
          if description.blank?
            data['supplier_num'] = product_data['supplier_num']
          else
            warning "Unknown description: #{description.inspect}"
            next
          end
        end

        puts "SupplierNum: #{data['supplier_num']}"

        if nums.include?(data['supplier_num'])
          warning "Duplicate supplier_num: #{data['supplier_num']}"
          next 
        end
        nums << data['supplier_num']

        next data if colors.empty?

        colors.collect do |color|
          data.merge('supplier_num' => (data['supplier_num'] + "-#{color}")[0..31],
                     'color' => color)
        end
      end.flatten.compact

      product_data['price_params'] = { :n1 => min_units, :m1 => 1.5, :n2 => max_units, :m2 => 1.2 }
      puts product_data['price_params'].inspect

      add_product(product_data)
    end
  end
end
