require 'rexml/document'
require 'net/ftp'

class LogoIncludedXML < GenericImport
  include REXML

  def initialize(file_name)
    @src_file = File.join(JOBS_DATA_ROOT,file_name)
    super "LogoIncluded"
  end

  def fetch
    puts "Fetching"
    remote_file = 'feed.xml'
    Net::FTP.open('ftp.logoincluded.com') do |ftp|
      ftp.login('mountainofpromos', 'Br3S9Ebr')
      if ftp.mtime(remote_file) < File.mtime(@src_file)
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
    File.open(@src_file) do |file|
      @doc = Document.new(file)
    end
    
    root = @doc.root.get_elements('/ProductList').first
    root.each_element do |product|
      # Product Record

      @product_id = "#{product.get_text('SKU')} #{product.get_text('Name')}"

      category = product.get_text('Category').to_s
      if %w(USB\ Accessories).include?(category)
        name = product.get_text('Name').to_s
      else
        name = (product.get_text('Name').to_s.split(' ')+category.split(' ')).reverse.uniq.reverse.join(' ')
      end
      product_data = {
        'supplier_num' => product.get_text('SKU').to_s,
        'name' => name,
        'supplier_categories' => [[category]],
        'description' => product.get_text('Description').to_s.gsub(/\.\s+/,".\n"),
        'data' => { :url => product.get_text('LogoincludedURL').to_s.strip }
      }

      url_string = product.get_text('LogoincludedURL').to_s.strip
      unless url_string.empty?
        unless /^http:\/\/www\.logoincluded\.com\/products\/(.+)$/ === url_string
          raise "Unknown URL: #{url_string}"
        end
        product_data['data'] = { :path => $1 }
      end
        


#      puts "Product: #{product_data['supplier_num']} : #{product_data['name']}"

      begin # Shipping
        ship_indiv = product.get_elements('ShippingInfo/IndividualWeight').first
#        raise "unit not g: #{ship_indiv.attributes.inspect}" unless ship_indiv.attributes['unit'] != 'g'
        ship_unit = product.get_elements('ShippingInfo/MasterCartonWeight').first
#        raise "unit not lbs" unless ship_unit.attributes['unit'] != 'lbs'
        master_qty = product.get_text('ShippingInfo/MasterCartonQty').to_s
        if master_qty.empty?
          warning "Empty Master Carton"
          master_qty = nil 
        end
        warning "Invalid MasterCartonQty: #{master_qty}" if master_qty.to_i.to_s != master_qty
        product_data.merge!({ 'package_unit_weight' => ship_indiv.text && (Float(ship_indiv.text) * 0.00220462262),
                              'package_units' => master_qty && master_qty.to_i,
                              'package_weight' => ship_unit.text && Float(ship_unit.text) })
      end

      begin # Lead Times
        production_time_reg = /(\d+)(?:-(\d+))? days?/
        std_time = product.get_text('ProductionTimes/StandardProductionTime').to_s
        unless std_time.blank?
          case std_time
          when /(\d+)(?:-(\d+))? days/
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
        
        rush_time = product.get_text('ProductionTimes/RushProductionTime').to_s
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

        list += product.get_elements('ImprintArea/Location').collect do |location|
          data = {
            'technique' => 'Screen Print',
            'limit' => 5,
            'location' => location.get_text('Description').to_s }

          { 'Length' => 'width',
            'Height' => 'height' }.each do |tag, attr|
            node = location.get_elements(tag).first
            raise "Unknown #{tag} unit" unless node.attributes['unit'] == 'mm'
            data[attr] = (Float(node.text) * 3.93700787).round / 100.0
          end

          data
        end
        product_data['decorations'] = list
      end

      begin # Product Image
        image_url = product.get_text('Image/Large').to_s
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
 
      colors = product.get_elements('ColorOptions/Color/Description').collect { |n| n.text }

      product_data['variants'] = product.get_elements('Pricing/LineItem').collect do |li|
        last_maximum = nil
        prices = li.get_elements('UnitPriceBreaks/Quantity').collect do |qty|
          min, max = %w(minimum maximum).collect { |n| qty.attributes[n].blank? ? nil : Integer(qty.attributes[n]) }
#          puts "Min: #{min} #{max}"
#          raise "Non sequential quantity" if last_maximum and (last_maximum == min - 1)
          last_maximum = max
          price = Money.new(Float(qty.get_elements('Price').first.text))
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

        description = li.attributes['description']
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

        next data if colors.empty?

        colors.collect do |color|
          data.merge('supplier_num' => (data['supplier_num'] + "-#{color}")[0..31],
                     'color' => color)
        end
      end.flatten.compact

      add_product(product_data)
    end
  end
end
