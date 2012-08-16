# -*- coding: utf-8 -*-

class GemlineXML < GenericImport
  @@decoration_replace = { 'Print' => ['Screen Print', 6],
  'Embroidery' => ['Embroidery', 20000],
  'Embroider' => ['Embroidery', 20000],
  'Deboss' => ['Deboss', 2],
  'Personalization' => ['Personalization', nil],
  'Patch' => ['Patch', nil],
  'LogoMagic' => ['LogoMagic', nil],
  'Gemphoto/Heat Transfers' => ['Photo Transfer', nil],
  'Gemphoto' => ['Photo Transfer', nil],
  'Print (one color only)' => ['Screen Print', 1],
  "Print (case only – one color print)" => ['Screen Print', 1],
  'Initials' => ['Personalization', nil],
  'Laser Engraving' => ['Laser Engrave', 1]}

  def fetch
    dst_path = File.join(JOBS_DATA_ROOT,'Gemline.xml')
    if File.exists?(dst_path) and
        File.mtime(dst_path) >= (Time.now - 24*60*60)
      puts "File Fetched today"
      return
    end
    
    puts "Starting Fetch"
    
    agent = Mechanize.new
    page = agent.get('http://www.gemline.com/MyGemline/index.aspx')
    form = page.forms.first
    form.fields.find { |f| f.name.include?('txtEmail') }.value = 'mtnexp'
    form.fields.find { |f| f.name.include?('txtPassword') }.value = 'Robert1'
    form.add_field!('ctl00$ContentPlaceHolder1$btnLogin.x','22')
    form.add_field!('ctl00$ContentPlaceHolder1$btnLogin.y','14')
    page = agent.submit(form)
    
    page = agent.get('http://www.gemline.com/MyGemline/distributor-tools/downloads.aspx')
    
    
    form = page.forms.first
    form.add_field!('__EVENTTARGET', 'ctl00$ContentPlaceHolder1$download1$lnkProductDataXML')
    form.add_field!('__EVENTARGUMENT', '')
    page = agent.submit(form)
    
    name = /filename=\"(.*)\"/.match(page.response['content-disposition'])[1]
    path = File.join(JOBS_DATA_ROOT,name)
    
    page.save_as path
    
    FileUtils.ln_sf(name, dst_path)
    
    puts "Fetched"
  end

  def initialize
    file_name = "Gemline.xml"
    @src_file = File.join(JOBS_DATA_ROOT,file_name)
    super "Gemline"
  end
  
  def parse_categories(element)
    return [] unless element
    categories = []
    element.elements.each do |category|
      first = category['name'].gsub('&amp;','&')
      category.elements.each do |sub|
        categories << [first, sub['name'].gsub('&amp;','&')]
      end
    end
    categories.uniq
  end
  
  def parse_products
    fetch

    puts "Reading XML"  
    doc = File.open(@src_file) { |f| Nokogiri::XML(f) }
    
    decoration_reg = /^([A-Za-z0-9 \(\),]+?) ?(?:(?:([0-9\.]+)"?W? ?x? ?([0-9\.]+)"?H?)|(?:([0-9\.]+)"? *(?:(?:dia.?)|(?:diameter))))?$/

    ProductDesc.over_each(self, doc.xpath('/xml/gemlineproductdata/product')) do |pd, product|
      prod_log_str = ''
       
      next if (product['isflyer'] == "True") or (product['iscatalog'] == "True") # We don't care about fylers

      # Product Record
      pd.supplier_num = product['mainstyle']
      pd.name = product['name']
      pd.description = product['description'].split('^')
      pd.data = { :id => product['Id'] }
      
      pd.lead_time.normal_min = 3
      pd.lead_time.normal_max = 5
      pd.lead_time.rush = 1

      pd.package.merge_from_object(product,
                                   { 'units' => 'products_per_box',
                                     'weight' => 'box_weight',
                                     'height' => 'box_height_inches',
                                     'width' => 'box_width_inches',
                                     'length' => 'box_length_inches' })
  
      dimension = {}
      %w(diameter length height width).each { |n| dimension[n] = product[n].to_f if product[n] and product[n].to_f != 0.0 }
      dimension = nil if dimension.empty?
  
      # Decorations
      begin
        list = [DecorationDesc.none]

        product.xpath('decorations/decoration').each do |decoration|
          technique = decoration["technique"]
          if @@decoration_replace[technique]
            technique, limit = @@decoration_replace[technique]
          else
            puts "!!!! UNKNOWN DECORATION: #{technique}"
          end
                  
          decoration.elements.each do |location|
            s = location.text.strip
            full, name, width, height, diameter = decoration_reg.match(s).to_a
            
            if full
              puts "#{pd.supplier_num}: #{name}" if name.split(' ').size == 2 and !name.index('panel')
              dd = DecorationDesc.new(:technique => technique,
                                      :location => name.strip.gsub(/\s+/, ' ').capitalize,
                                      :limit => limit)
              dd.width = width if width
              dd.height = height if height
              dd.diameter = diameter if diameter
           
              list << dd
            else
              prod_log_str << " * Unknown decoration: #{s}\n"
            end
          end
        end
        pd.decorations = list
      end
  
      # related-products
      #prods = []
      #related = product.get_elements('related-products').first
      #related.each_element do |rel_prod|
      #  prods << @@product_prefix + rel_prod.attributes['mainstyle']
      #end
      #prod['related'] = prods
  
      prod_categories = nil

      # items
      xml_items = product.xpath('items/item')
      material = xml_items.first && xml_items.first['fabric'] # Kludge to assume same material for all variants
        
      items = xml_items.collect do |item|
        val = {
          'num' => item['style'],
          'color' => item['color'],
          'material' => material
        }

        if swatches_element = item.at_xpath('swatches')
          swatches = {}
          swatches_element.elements.each do |image|
            swatches[image.name] = image['path'] + image['name']
          end
          val['swatches'] = swatches
        end

        if image_node = item.at_xpath('images/zoomed')
          val['images'] = [ImageNodeFetch.new(image_node['name'], "#{image_node['path']}#{image_node['name']}")]

          item.at_xpath('images/alternate-images').elements.each do |alt|
            if /zoomed(\d)/ === alt.name
              val['images'] << ImageNodeFetch.new("alts/#{alt['name']}", "#{alt['path']}#{alt['name']}".gsub('\\','/'))
            end
          end
        end

        prices = []
        last_max = nil
        item.xpath("pricing[@type='US']/price").each do |price|
          br = /(\d+)[-+](\d+)?/.match(price['break'])
          prod_log_str << " * Non contigious prices" if last_max and br[1].to_i != last_max + 1
          last_max = br[2] ? br[2].to_i : nil
          price_val = price.text[1..-1].to_f
          next if prices.last and prices.last[1] == price_val
          prices << [ br[1].to_i, price_val, convert_pricecode(price['code']) ]
        end
        if prices.empty?
          puts "NO PRICES: #{val['num']}"
          next
        end
        val['prices'] = prices

        categories = parse_categories(item.at_xpath('categories'))
        collections = item.at_xpath('collections')
        categories += parse_categories(collections).collect { |e| ['Collections'] + e }
        if prod_categories
          if prod_categories != categories
            raise "Inconsistent categories: #{prod_categories.inspect} != #{categories.inspect}"
          end
        else
          prod_categories = categories.uniq
        end

        val
      end.compact

      prod_categories ||= []

      if uses = product.xpath('product-uses/uses')
        prod_categories += uses.collect { |use| ['Uses', use['name']] }
      end

      # Turn closeout/new category to tag
      prod_categories.delete_if do |category|
        delete = nil
        { 'Clearance' => 'Closeout',
          'New Products' => 'New',
          'Eco-Choice' => 'Eco' }.each do |cat, tag|
          if category.include?(cat)
            pd.tags << tag unless pd.tags.include?(tag)
            delete = true
          end
        end
        delete
      end
      pd.supplier_categories = prod_categories


      hash = {}
      hash.default = []
      maximum = items.collect do |item|
        hash[prices = item.delete('prices')] += [item]
        [prices.first.first * 10, prices.last.first].max
      end.max
              
      pd.variants = hash.collect do |prices, list|
        marginal = Money.new((prices.last[1] * (1.0 - prices.last[2]))).round_cents
        if prices.last[2] > 0.4
          pd.tags << 'Special'
        end
        costs = [
            { :fixed => Money.new(60.00),
              :minimum => (prices.first[0] / 2.0).ceil,
              :marginal => marginal,
            },
            { :fixed => Money.new(0),
              :minimum => prices.first.first.to_i,
              :marginal => marginal,
            },
            { :minimum => (maximum * 1.5).to_i }
            ]
        
        prices = prices.collect { |p| {:minimum => p[0], :marginal => Money.new(p[1]).round_cents, :fixed => Money.new(0)} }
      
        list.collect do |variant|
          vd = VariantDesc.new(:supplier_num => variant['num'])
          vd.properties = { 
            'material' => variant['material'],
            'dimension' => dimension,
            'color' => variant['color']
          }
          vd.images = variant['images']
          vd.pricing = PricingDesc.new(prices, costs)
 
#          %w(small medium).each do |name|
#            data["swatch-#{name}"] = CopyImageFetch.new(variant['swatches'][name]) if variant['swatches'][name]
#          end
          vd
        end
      end.flatten # hash.each

#      add_product(pd)
    end # gemroot.each_element
  end
end
