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
    doc = File.open(@src_file) { |f| Nokogiri::XML(f.read.gsub('&', '&amp;')) }
    
    doc.xpath('/ProductList/Product').each do |product|
      ProductDesc.apply(self) do |pd|
        # Product Record
        @product_id = "#{product.at_xpath('SKU').text} #{product.at_xpath('Name').text}"
        
        pd.supplier_num = product.at_xpath('SKU').text
        
        category = product.at_xpath('Category').text
        if %w(USB\ Accessories SD\ Cards\ \ Readers).include?(category)
          pd.name = product.at_xpath('Name').text
        else
          pd.name = (product.at_xpath('Name').text.split(' ')+category.split(' ')).reverse.uniq.reverse.join(' ')
        end
        pd.supplier_categories = [[category]]
        
        pd.description = product.at_xpath('Description').text.gsub(/\.\s+/,".\n")
        
        
        begin # Shipping
          ship_indiv = product.at_xpath('ShippingInfo/IndividualWeight')
          raise "unit not g: #{ship_indiv.attributes.inspect}" unless ship_indiv.attributes['unit'].value == 'g'
          pd.package.unit_weight = ship_indiv.text.blank? ? nil : (Float(ship_indiv.text) * 0.00220462262)
          
          ship_weight = product.at_xpath('ShippingInfo/MasterCartonWeight')
          raise "unit not lbs" unless ship_weight.attributes['unit'].value == 'lbs'
          pd.package.weight = ship_weight.text.blank? ? nil : Float(ship_weight.text)
          
          
          master_qty = product.at_xpath('ShippingInfo/MasterCartonQty').text
          if master_qty.blank?
            warning "Empty Master Carton" if pd.package.unit_weight || pd.package.weight
            master_qty = nil
          else
            warning "Invalid MasterCartonQty: #{master_qty}" if master_qty.to_i.to_s != master_qty
            pd.package.units = Integer(master_qty)
          end
        end
        
        begin # Lead Times
          production_time_reg = /(\d+)(?:-(\d+))?(?: +business)? +((?:days)|(?:weeks))/i
          std_time = product.at_xpath('ProductionTimes/StandardProductionTime').text
          unless std_time.blank?
            unless production_time_reg === std_time
              raise "Unknown std time: #{std_time.inspect}"
            end
            multi = ($3 == 'weeks') ? 5 : 1
            pd.lead_time.normal_min = Integer($1) * multi
            pd.lead_time.normal_max = Integer($2 || $1) * multi
          end
          
          rush_time = product.at_xpath('ProductionTimes/RushProductionTime').text
          unless rush_time.blank? or %w(None n/a).include?(rush_time.strip)
            if production_time_reg === rush_time
            pd.lead_time.rush = Integer($1)
            else
              warning "Unknown rush time: #{rush_time.inspect}" 
            end
          end
        end
        
        begin # Decorations
          pd.decorations = [DecorationDesc.none]
          
          pd.decorations += product.xpath('ImprintArea/Location').collect do |location|
            dd = DecorationDesc.new(:technique => 'Screen Print',
                                    :location => location.at_xpath('Description').text,
                                    :limit => 5)
            
            { 'Length' => 'width',
              'Height' => 'height' }.each do |tag, attr|
              node = location.at_xpath(tag)
              raise "Unknown #{tag} unit" unless node['unit'] == 'mm'
              dd[attr] = (Float(node.text) * 3.93700787).round / 100.0 unless node.text.blank?
            end
            
            dd
          end
        end
        
        begin # Product Image
        image_url = product.at_xpath('Image/Large').text
          unless image_url.blank?
            pd.images = [ImageNodeFetch.new(pd.supplier_num, image_url)]
          else
            warning "Unspecified image"
            next
          end
        end
        
        min_units = 10000000
        max_units = 0
        
        pd.variants = product.xpath('Pricing/LineItem').collect do |li|
          last_maximum = nil
          prices = li.xpath('UnitPriceBreaks/Quantity').collect do |qty|
            min, max = %w(minimum maximum).collect { |n| qty[n].blank? ? nil : Integer(qty[n]) }
            if min and max and max < min
              warning "EXCLUDING: #{max} < #{min}"
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
          
          #        puts "#{pd.supplier_num}: #{prices.inspect} #{costs.inspect}"
          
          vd = VariantDesc.new
          vd.pricing = PricingDesc.new(prices, costs)
          vd.images = [] # Suppress warning
          
          description = li['description']
          case description
          when /(\d+(?:(?:MB)|(?:GB?))) (USB ([23]).0)/
          vd.properties['memory'] = $1
            vd.properties['speed'] = $2
            vd.supplier_num = pd.supplier_num + "-#{$1}"
            vd.supplier_num += "-#{$3}" unless $3 == '2'
          else
            if description.blank?
              vd.supplier_num = pd.supplier_num
            else
              warning "Unknown description: #{description.inspect}"
              next
            end
          end

          vd
        end.compact
        
        colors = product.xpath('ColorOptions/Color/Description').collect { |n| { 'color' => n.text } }.uniq
        pd.variants_multiply_properties(colors)

        if /(?:finishes\s*\((.+?)\))|(?:choose\s+from\s+(.+?)\s+finish\s+)/ === pd.description
          list = ($1 || $2).split(/\s*(?:,|and|or)\s*/)
          pd.variants_multiply_properties(list.collect { |s| { 'finish' => s.capitalize } } )
        end
        
        pd.pricing_params = { :n1 => min_units, :m1 => 1.5, :n2 => max_units, :m2 => 1.2 }
      end
    end
  end
end
