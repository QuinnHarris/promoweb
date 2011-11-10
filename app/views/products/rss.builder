xml.instruct! :xml, :version=> '1.0', :encoding => 'UTF-8'
xml.rss :version => '2.0', 'xmlns:g' => 'http://base.google.com/ns/1.0' do
  xml.channel do
    xml.title "Mountain of Promos Products"
    xml.link "http://www.mountainofpromos.com/"
    xml.description "Promotional Products"

    @products_scope.find_in_batches(:batch_size => 200) do |products|
      GC.start
      properties = Property.find_by_sql([
        "SELECT DISTINCT properties.name, properties.value, variants.product_id FROM properties JOIN properties_variants ON properties.id = properties_variants.property_id " +
        "JOIN variants ON properties_variants.variant_id = variants.id WHERE variants.product_id IN (?)" +
        "ORDER BY variants.product_id", product_ids = products.collect { |p| p.id }])

      prod_cat_map = {}
      Category.find_by_sql(["SELECT product_id, category_id FROM categories_products WHERE product_id IN (?)", product_ids]).each do |cp|
        product_id, category_id = cp.product_id.to_i, cp.category_id.to_i
        prod_cat_map[product_id] = (prod_cat_map[product_id] || []) + [category_id]
      end
    
      products.each do |product|
        begin # Apply properties to product
          hash = {}
          while (prop = properties.first) and (prop.product_id.to_i == product.id)
            hash[prop.name] = (hash[prop.name] || []) + [prop.translate]
            properties.shift
          end
          product.instance_variable_set("@properties_get", hash)
        end

        xml.item do
          xml.tag!('id', product.id)

          description = ''
          
          # Product name with price
          suffix = " (#{product.price_shortstring_cache})"
          midfix = []
          name = product.name
          max_length = 48
          if name.length + suffix.length > max_length
            description += "#{name} - Custom Printed\n"
            name = name[0...(max_length - suffix.length)]
          else
            [' - Custom', 'Printed'].each do |word|
              if name.length + suffix.length + midfix.join(' ').length + word.length <= max_length
                midfix << word
              end
            end
          end

          title = (name.strip + midfix.join(' ') + suffix).encode('ASCII', :invalid => :replace, :undef => :replace, :replace => '')

          xml.title title
          
          xml.link "http://www.mountainofpromos.com/products/#{product.web_id}"
          
          
          # Description
          description += "(#{product.price_fullstring_cache})\n"
          
          imprints = product.decorations.collect { |d| d.technique.name }.uniq.find_all { |n| n != 'None' }
          description += "Custom #{imprints.join(', ')}\n" unless imprints.empty?
          
          description += product.description.gsub("\n",".\n")
          xml.description description.encode('ASCII', :invalid => :replace, :undef => :replace, :replace => '')
          
          prop = product.properties_get
          %w(color material size).each do |name|
            xml.tag!("g:#{name}", prop[name].join(',').encode('ASCII', :invalid => :replace, :undef => :replace, :replace => '')) if prop[name]
          end
          if prop['dimension']
            dim = prop['dimension'].split(',').inject({}) do |hash, str|
              name, value = str.split(':')
              hash[name] = value
              hash
            end
            %w(height width length).each do |name|
              xml.tag!("g:#{name}", dim[name]) if dim[name]
            end
          end
          
          #        xml.tag!('g:expiration_date', @expiration_date)
          
          xml.tag!('g:condition', 'new')
          
          if product.product_images.empty?
            images = ["data/product/#{product.id}/#{product.id}_large_1.jpg"]
          else
            images = product.product_images.to_a.sort_by { |i| i.variants.empty? ? 0 : 1 }.collect { |i| i.image.url(:medium) }
          end
          xml.tag!('g:image_link', "http://www.mountainofpromos.com#{images.first}")
          images[1..10].each do |i|
            xml.tag!('g:additional_image_link', "http://www.mountainofpromos.com/#{i}")
          end
          
          xml.tag!('g:brand', product.supplier.name)
          xml.tag!('g:mpn', product.supplier_num)
          
          xml.tag!('g:availability', 'available for order')
          xml.tag!('g:price', product.price_comp_cache)
          

	  categories = (prod_cat_map[product.id] || []).collect do |id|
	    Category.find_by_id(id)
	  end

          for cat in categories.to(9)
            xml.tag!('g:product_type', cat.path_name_list.join(' > ').encode('ASCII', :invalid => :replace, :undef => :replace, :replace => '')) if cat
          end

          google_categories = categories.collect { |c| c.google_category.blank? ? nil : c.google_category }.compact	
          while !categories.empty? and google_categories.empty?
            categories = categories.collect { |c| c.parent == Category.root ? nil : c.parent }.compact.uniq
            google_categories = categories.collect { |c| c.google_category.blank? ? nil : c.google_category }.compact
          end
          
          unless google_categories.empty?
            xml.tag!('g:google_product_category', google_categories.sort_by { |c| [c.split('>').length, c.length] }.last)

            if google_categories.first.include?('Apparel')
              case title+description
                when /(female)|(ladie)|(woman)/i
                xml.gender 'Female'
                when /(male)|(men)/i
                xml.gender 'Male'
              else
                xml.gender 'Unisex'
              end

              xml.age_group 'Adult'
            end
          end
          
          xml.tag!('online_only', 'y')
        
          # color
          # apparel_type
          # brand
          # expiration_date
          # memory
          # model_number
          # price_type
          # quantity
          # shipping
        end
      end
    end
  end
end
