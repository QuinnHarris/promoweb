require 'csv'

class AlphaBroder < GenericImport
  # https://www.alphabroder.com/cgi-bin/download/webshr/prod-info-view.w?f=alp-AllStyles_R064.tar.gz
  def initialize()
    @file_name = 'alp-AllStyles_R064.tar.gz'
    @src_directory = File.join(JOBS_DATA_ROOT, 'alphabroder')
    @src_file = File.join(JOBS_DATA_ROOT, @file_name)

    super "Alphabroder"
  end

  def fetch_parse_notworking?
    agent = Mechanize.new
    page = agent.get('http://www.alphabroder.com/')
    form = page.form_with name: 'frmLogin'
    form.field_with(name: 'userName').value = 'MountainXpress'
    form.field_with(name: 'password').value = 'promomountain'
    in_page = agent.submit form

    data_page = agent.get("https://www.alphabroder.com/cgi-bin/download/webshr/prod-info-view.w?f=#{@file_name}")
    data_page.save_as @src_file

    

    wf = WebFetch.new()
  end

  def CSV_foreach(file, &block)
    CSV.foreach(File.join(@src_directory, file), encoding: "ISO-8859-1", headers: :first_row, &block)
  end

  def parse_products
    puts "Load Attributes"
    @style_attributes = {}
    CSV_foreach('style-attribute-values.csv') do |row|
      next if row['Value'] == '0'
      style = (@style_attributes[row['Style Number']] ||= {})
      attr = (style[row['Size']] ||= {})
      name = row['Attribute'].split(' ').map { |s| s.capitalize }.join(' ')
      attr[name] = row['Value']
    end

    puts "Load Features"
    feature_map_cols = %w(product-code feature-code)
    @feature_keys = {}
    CSV_foreach('features.csv') do |row|
      @feature_keys[feature_map_cols.map { |c| row[c] }] = row['description']
    end

    @style_features = {}
    CSV_foreach('style-features.csv') do |row|
      next if row['description'].blank? or %w(No None).include?(row['description'])
      keys = feature_map_cols.map { |c| row[c] }
      if keys.find { |k| k.blank? }
        @supplier_num = row['style-code']
        warning "Unexpected Style Feature", keys
        next
      end
      feature_key = @feature_keys[keys]
      raise "Unknown feature: #{row['style-code']}: #{row['product-code']}, #{row['feature-code']}" unless feature_key

      features = (@style_features[row['style-code']] ||= {})
      features[feature_key] = row['description']
    end

    puts "Load Items"
    @items = {}
    CSV_foreach('items_R064.csv') do |row|
      items = (@items[row['Style Code']] ||= [])
      items << row
    end

    # Main Data
    puts "Main Loop"
    CSV_foreach('styles.csv') do |row|
      next if row['Category Code'] == 'EMB'
      next if row['Mill Name'] == 'Gemline'
      ProductDesc.apply(self) do |pd|
        # - Company
        pd.supplier_num = row['Style Code']
        pd.name = row['Description']

        string_map = {
            ';'      => "\n",
            '&#244;' => '&ldquo;',
            '&#245;' => '&rdquo;' }
        pd.description = row['Features'].split(/(?:\s*(;)\s*)|(&#?[a-z0-9]+?;)/i).map { |s| string_map[s] || s }.join.strip
        domain = row['Domain']
        image_path = row['ProdDetail Image']
        image_id = image_path.split('/').last
        #pd.images = images = [ImageNodeFetch.new(image_id, domain + image_path)]
        pd.images = []

        # - Mill-Category
        # - Mill Code
        # - Category Code
        # - Item Count

        pd.brand = row['Mill Name']
        pd.supplier_categories = [[row['Category Name']]]
        # Popularity

        items = @items[pd.supplier_num]
        unless items.length != row['Item Count']
          warning "Item Count Mismatch", "#{items.length} != rows['Item Count']"
        end

        pd.tags = TagsDesc.new
        if features = @style_features[pd.supplier_num]
          if special_collections = features.delete('Special Collections')
            pd.supplier_categories << ['Collections', special_collections]
          end
          if features.delete('Earth-Friendly') == 'Yes'
            pd.tags << 'Eco'
          end
          pd.properties.merge!(features) if features
        end

        pd.lead_time.normal_min = 3
        pd.lead_time.normal_max = 10

        attributes_by_color = @style_attributes[pd.supplier_num]
        attribute_keys = attributes_by_color.map { |s, a| a.keys }.flatten.uniq if attributes_by_color

        pd.package.units = 1000000000
        pd.package.unit_weight = 0

        pd.variants = items.map do |item|
          # - Company
          vd = VariantDesc.new(supplier_num: item['Item Number'])
          # - Description
          # - Features

          pd.package.units = [Integer(item['Pack Qty']), pd.package.units].min
          pd.package.unit_weight = [Float(item['Weight']), pd.package.unit_weight].max

          vd.pricing.add(1, item['Retail Price'], Float(item['Piece']))
          vd.pricing.add(12, nil, item['Dozen'])
          #if Integer(item['Pack Qty']) == 0
          #  warning "Pack Qty 0"
          #else
          #  vd.pricing.add(item['Pack Qty'], nil, item['Dozen'])
          #end
          vd.pricing.add(item['Case Qty'], nil, item['Case']) unless Integer(item['Pack Qty']) <= 12
          #vd.pricing.maxqty(500)

          vd.properties['size'] = item['Size Name']
          # - Size Category
          # - Size Code
          vd.properties['color'] = item['Color Name'].split(/(\s+|\/)/).map { |c| c.capitalize }.join
          # - Hex Code
          # - Color Code
          # - Weight

          if attributes_by_color
            attributes = attributes_by_color[item['Size Name']] || {}
            attribute_keys.each { |key| attributes[key] ||= nil }
            vd.properties.merge!(attributes)
          end

          #vd.images = []
          #domain = item['Domain']
          # (%w(Detail Gallery).map { |n| ["Prod#{n} Image", n]} +
          #  %w(Front Back Side).map { |n| ["#{n} of Image Name", n]}).each do |key, name|
          #   image_path = item[key]
          #   image_id = image_path.split('/').last
          #   unless vd.images.find { |i| i.id == image_id }
          #     image = images.find { |i| i.id == image_id }
          #     unless image
          #       image = ImageNodeFetch.new(image_id, domain + image_path, name)
          #       images << image
          #     end
          #     vd.images << image
          #   end
          # end
          vd.images =
              { 'Front' => 'fr',
                'Back'  => 'bk',
                'Side'  => 'sd' }.map do |name, a|
            next if item["#{name} of Image Name"].blank?
            ImageNodeFetch.new("#{item['Color Code']}-#{a}", "http://www.abmarketingengine.com/index.php/api/image/download?style=#{pd.supplier_num}&color_code=#{item['Color Code']}&oid=1&angle=#{a}")
          end.compact

          if vd.images.empty?
            domain = item['Domain']
            vd.images = %w(Detail Gallery).map do |n|
              image_path = item["Prod#{n} Image"]
              next if image_path.blank?
              image_id = image_path.split('/').last
              ImageNodeFetch.new(image_id, domain + image_path, n)
            end.compact
          end

          # - Style Number
          # - GTIN Number
          # - Max Inventory
          # - Closeout
          # - Mill Name
          # - Launch Date
          # - Coming Soon

          vd
        end

        %w(Front Back).each do |location|
          pd.decorations << DecorationDesc.new(technique: 'Screen Print',
                                               limit: 6, location: location)

          pd.decorations << DecorationDesc.new(technique: 'Embroidery',
                                               limit: 15000, location: location)
        end
      end
    end
  end
end
