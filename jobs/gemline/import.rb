require 'rexml/document'

class GemlineXML < GenericImport
  include REXML
#  include XML

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
  "Print (case only \342\200\223 one color print)" => ['Screen Print', 1],
  'Initials' => ['Personalization', nil],
  'Laser Engraving' => ['Laser Engrave', 1]}

  def initialize(file_name)
    @src_file = File.join(JOBS_DATA_ROOT,file_name)
    super "Gemline"
  end
  
  def parse_categories(element)
    categories = []
    element.each_element do |category|
      first = category.attributes['name'].gsub('&amp;','&')
      category.each_element do |sub|
        categories << [first, sub.attributes['name'].gsub('&amp;','&')]
      end
    end
    categories.uniq
  end
  
  def to_utf(str)
    str.unpack("C*").map do |c|
        if c < 0x80
            next c.chr
        elsif c < 0xC0
            next "\xC2" + c.chr
        else
            next "\xC3" + (c - 64).chr
        end
    end.join('')
  end

  def parse_products
    puts "Reading XML"  
    File.open(@src_file) do |file|
      @doc = Document.new(file)
    end
    
    break_reg = /(\d+)[-+](\d+)?/
    decoration_reg = /^([A-Za-z0-9 \(\),]+?) ?(?:(?:([0-9\.]+)"?W? ?x? ?([0-9\.]+)"?H?)|(?:([0-9\.]+)"? *(?:(?:dia.?)|(?:diameter))))?$/

    gemroot = @doc.root.get_elements('gemlineproductdata').first
    gemroot.each_element do |product|
      prod_log_str = ''
       
      attr = product.attributes
      next if (attr['isflyer'] == "True") or (attr['iscatalog'] == "True") # We don't care about fylers

      # Product Record
      prod_data = {
        'supplier_num' => attr['mainstyle'],
        'name' => attr['name'].strip,
        'lead_time_normal_min' => 3,
        'lead_time_normal_max' => 5,
        'lead_time_rush' => 1,
        'description' => attr['description'].split('^').delete_if { |s| s.empty? }.join("\n"),
        'package_weight' => attr['box_weight'].to_f,
        'package_units' => attr['products_per_box'].to_i,
        'package_unit_weight' => 0.0,
        'package_height' => attr['box_height_inches'].to_f,
        'package_width' => attr['box_width_inches'].to_f,
        'package_length' => attr['box_length_inches'].to_f,
        'data' => { :id => attr['Id'] }
      }
  
      dimension = {}
      %w(diameter length height width).each { |n| dimension[n] = attr[n].to_f if attr[n] and attr[n].to_f != 0.0 }
      dimension = nil if dimension.empty?
  
      # Decorations
      begin
        list = [{
          'technique' => 'None',
          'location' => ''
        }]
        decorations = product.get_elements('decorations').first
        decorations.get_elements('decoration').each do |decoration|
          technique = decoration.attributes["technique"]
          if @@decoration_replace[technique]
            technique, limit = @@decoration_replace[technique]
          else
            puts "!!!! UNKNOWN DECORATION: #{technique}"
          end
                  
          decoration.each_element do |location|
            s = location.text.gsub(/[\200-\350]+/,' ')
            full, name, width, height, diameter = decoration_reg.match(s).to_a
            
            if full
              puts "#{prod_data['supplier_num']}: #{name}" if name.split(' ').size == 2 and !name.index('panel')
              elem = {
                'technique' => technique,
                'limit' => limit,
                'location' => name.strip.split(' ').join(' ').capitalize }  # Do we still need this?
              elem['width'] = width.to_f if width
              elem['height'] = height.to_f if height
              elem['diameter'] = diameter.to_f if diameter          
           
              list << elem
            else
              prod_log_str << " * Unknown decoration: #{s}\n"
            end
          end
        end
        prod_data['decorations'] = list
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
      items = []
      product.get_elements('items/item').each do |item|
        val = {}
        attr = item.attributes
        val['num'] = attr['style']
        val['color'] = attr['color']
        val['material'] = attr['fabric']

        if swatches_element = item.get_elements('swatches').first
          swatches = {}
          swatches_element.each_element do |image|
            swatches[image.name] = image.attributes['path'] + image.attributes['name']
          end
          val['swatches'] = swatches
        end

        if image_node = item.get_elements('images/zoomed').first
          val['images'] = [ImageNodeFetch.new(val['num'], "#{image_node.attributes['path']}#{image_node.attributes['name']}")]

          item.get_elements('images/alternate-images/').first.each_element do |alt|
            if /zoomed(\d)/ === alt.name
              val['images'] << ImageNodeFetch.new("#{val['num']}-#{$1}", "#{alt.attributes['path']}#{alt.attributes['name']}")
            end
          end
        end

        prices = []
        last_max = nil
        item.get_elements('pricing').first.each_element do |price|
          br = break_reg.match(price.attributes['break'])
          prod_log_str << " * Non contigious prices" if last_max and br[1].to_i != last_max + 1
          last_max = br[2] ? br[2].to_i : nil
          price_val = price.text[1..-1].to_f
          next if prices.last and prices.last[1] == price_val
          prices << [ br[1].to_i, price_val, convert_pricecode(price.attributes['code']) ]
        end
        if prices.empty?
          puts "NO PRICES: #{val['num']}"
          next
        end
        val['prices'] = prices

        categories = parse_categories(item.get_elements('categories').first)
        collections = item.get_elements('collections')
        categories += parse_categories(collections.first).collect { |e| ['Collections'] + e } unless collections.empty?
        if prod_categories
          if prod_categories != categories
            raise "Inconsistent categories: #{prod_categories.inspect} != #{categories.inspect}"
          end
        else
          prod_categories = categories.uniq
        end

        items << val
      end

      prod_categories ||= []

      if uses = product.get_elements('product-uses/uses')
        prod_categories += uses.collect { |use| ['Uses', use.attributes['name']] }
      end
  
      if prod_categories.empty?
        puts "No categories: #{prod_data['supplier_num']}"
#        next
      end

      # Turn closeout/new category to tag
      prod_categories.delete_if do |category|
        delete = nil
        { 'Clearance' => 'Closeout',
          'New Products' => 'New',
          'Eco-Choice' => 'Eco' }.each do |cat, tag|
          if category.include?(cat)
            prod_data['tags'] = (prod_data['tags'] || []) + [tag]
            delete = true
          end
        end
        delete
      end
      prod_data['tags'].uniq! if prod_data['tags']
      prod_data['supplier_categories'] = prod_categories


      hash = {}
      hash.default = []
      maximum = items.collect do |item|
        hash[prices = item.delete('prices')] += [item]
        [prices.first.first * 10, prices.last.first].max
      end.max
              
      prod_data['variants'] = hash.collect do |prices, list|
        marginal = Money.new((prices.last[1] * (1.0 - prices.last[2]))).round_cents
        if prices.last[2] > 0.4
          prod_data['tags'] ||= ['Special']
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
          data = {
            'supplier_num' => variant['num'],
            'material' => variant['material'],
            'images' => variant['images'],
            'dimension' => dimension,
            'prices' => prices,
            'costs' => costs,
            'color' => variant['color']
          }
 
          %w(small medium).each do |name|
            data["swatch-#{name}"] = CopyImageFetch.new(variant['swatches'][name]) if variant['swatches'][name]
          end
          data
        end
      end.flatten # hash.each

      add_product(prod_data)
    end # gemroot.each_element
  end
end
