class NorwoodAll < GenericImport
  def initialize
    @year = (Date.today + 7).year
    @colors = %w(Black White 186 202 208 205 211 1345 172 Process\ Yellow 116 327 316 355 341 Process\ Blue 293 Reflex\ Blue 281 2587 1545 424 872 876 877)
    @list =
      [['AUTO', 'Barlow'],
       ['AWARD', 'Jaffa'],
       ['BAG', 'AirTex'],
       ['CALENDAR', 'TRIUMPH', %w(Reflex\ Blue Process\ Blue 032 185 193 431 208 281 354 349 145 469 109 Process\ Yellow 165)],
       ['DRINK', 'RCC'],
       ['GOLF', 'TeeOff'],
       ['GV', 'GOODVALU'],
       ['HEALTH', 'Pillow'],
       ['OFFICE', 'EOL'],
       ['WRITE', 'Souvenir', @colors + %w(569 7468 7433)],
       ['FUN', 'Fun'],
       ['HOUSEWARES', 'Housewares'],
       ['MEETING', 'Meeting'],
       ['TECHNOLOGY', 'Technology'],
       ['OUTDOOR', 'Outdoor'],
       ['TRAVEL', 'Travel'],
      ]
    super 'Norwood'
  end

  attr_reader :year, :colors, :list

  def fetch
    @list.each do |file, name|
      wf = WebFetch.new("http://norwood.com/files/productdata/#{year}/#{year} CSV #{file}.zip")
      path = wf.get_path(Time.now - 30.days)
      dst_path = File.join(JOBS_DATA_ROOT,'norwood')
      dst_file = File.join(dst_path,"#{year} CSV #{file}.csv")
      unless File.exists?(dst_file)
        #    File.unlink(dst_file)
        puts "unzip #{path} -d #{dst_path}"
        system("unzip #{path} -d #{dst_path}")
      end
    end

    # Get Image List
    directory_list = %w(2012_Hardgoods_Hi_Res_Imprint_Images 2012_NPS3_Hi-Res_Images 2013_Calendars_Hi_Res_Imprint_Images 2012_Hardgoods_Hi_Res_Blank_Images 2013_Calendars_Hi_Res_Blank_Images 2012_Lifestyle_Images/2012_High_Res_Images).collect { |p| "Norwood 2012 Product Images/#{p}" }

    @image_list = cache_marshal('Norwood_imagelist') do
      get_ftp_images({ :server => 'library.norwood.com',
                       :login => 'images', :password => 'norwood' },
                     directory_list, /Hi[-_]Res/i) do |path, file|
        next nil if file.include?('\\') # kludge to deal with \ in file name causing bad URI
        if /\/([A-Z]{2}?\d{4,5})(?:_13)?(?:\/|$)/ === path
          product = $1
          if /^([A-Z]{2}?\d{4,5})(?:_(.+))?\.jpg$/i === file && $1 == product
            [path.split('/')[1..-1].join('/')+'/'+file, product, $2, (/blank/i === path) ? 'blank' : nil]
          end
        end
      end
    end
  end

  def apply_all(klass = NorwoodCSV)
    list.each do |file, name, c|
      import = klass.new("norwood/#{year} CSV #{file}.csv", name, @image_list)
      import.set_standard_colors(c || @colors)
      import.run_parse_cache
      import.run_transform
      import.run_apply_cache
    end
  end

  def import_list
    return @import_list if @import_list
    @import_list = list.collect do |file, name, c|
      NorwoodCSV.new("norwood/#{year} CSV #{file}.csv", name)
    end
  end

  %w(parse_cache transform apply_cache).each do |name|
    define_method "run_#{name}" do
      import_list.each { |i| i.send("run_#{name}") }
    end
  end
end

#"Brand","Brand Name","Price Includes","Keywords","Country of Origin","Features","Small Image","Medium Image","Large Image","Zoom Image","Small Image URL","Medium Image URL","Large Image URL","Zoom Image URL",""Page Number","Price Message","Price Start Date","Quantity","Price","Net Price","Late Pricing Start Date","Late Quantities","Late Prices","Late Net Prices","EQP Net Minus 3%","EQP Net Minus 5%","Customer Price","Unit of Measure","Sizes","Size Name","Size Width","Size Length","Size Height","Rush Lead Time","Additional Lead Time to Canada","Canadian Lead Time","Selections","Proofs","Item Color Charges","Option Charges","Additional Product Information","FOB Ship From City","FOB Ship From State","FOB Ship From Zip","FOB Bill From City","FOB Bill From State","FOB Bill From Zip"

require 'csv'
class NorwoodCSV < GenericImport
  @@technique_replace = {
    'Offset' => '?'
  }

  def initialize(file_name, sub_supplier, image_list)
    @file_name = file_name
    @image_list = image_list
    super ["Norwood", sub_supplier]
  end

  attr_reader :doc
  
  @@sufixes = {
    %w(CALENDAR APPT) => 'Calendar',
    %w(GV GV_APPT) => 'Calendar',
    %w(CALENDAR COMM) => 'Calendar',
    %w(CALENDAR CUSTOM) => 'Calendar',
    %w(CALENDAR EXEC) => 'Calendar',
    %w(GV GV_BUSINESS) => 'Calendar',
    %w(CALENDAR NODATE) => 'Calendar',
    %w(CALENDAR NUDE) => 'Calendar',
    %w(CALENDAR POCKET) => 'Calendar',
    %w(GV GV_MINI) => 'Calendar',
    %w(CALENDAR SUC) => 'Calendar',

  }

  def parse_products
    puts "Reading: #{@file_name}"

    CSV.foreach(File.join(JOBS_DATA_ROOT,@file_name), :headers => :first_row) do |row|
      ProductDesc.apply(self) do |pd|
        pd.supplier_num = @supplier_num = row['Product ID']
        pd.name = row['Product Name']
        pd.description = row['Product Description']
        pd.supplier_categories = [%w(Category Sub-Taxonomy).collect { |n| row[n] }]


        # Calendar Kludge
        if sufix = @@sufixes[pd.supplier_categories.first]
          unless pd.name.downcase.include?(sufix.downcase)
            pd.name << " #{sufix}"
            puts "Append: #{pd.supplier_num}: #{product_data['name']}"
          end
        end
        
        if row['Country of Origin'] == 'United States'
          pd.tags = %w(MadeInUSA)
        end

        # Package
        pd.package.units = Integer(row['Pack Size'])
        unless row['Pack Weight'].blank? or (row['Pack Weight'] == 'NA')
          raise "Unkown weight: #{row['Pack Weight']}" unless /^(\d+(?:\.\d)?) ?(?:((?:lbs?)|(?:oz))\.?)?$/ === row['Pack Weight']
          pd.package.weight = Float($1) * (($2 == 'oz') ? (1.0/16.0) : 1.0)
        end
        
        unless (leadtime = row['Lead Time']).blank?
          pd.lead_time.normal_min = pd.lead_time.normal_max = Integer(leadtime)
        end
        unless (leadtime = row['Rush Lead Time']).blank?
          pd.lead_time_rush = Integer(leadtime)
        end
        
        
        # Imprint
        pd.decorations = [DecorationDesc.none]
        (1..6).each do |num|
          dec = DecorationDesc.new
          break if (technique = row["Imprint Method#{num}"]).blank?
          if @@technique_replace.has_key?(technique)
            dec.technique = @@technique_replace[technique]
          else
            if DecorationDesc.technique?(technique)
              dec.technique = technique
            else
              warning "Unknown Technique", technique
              next
            end
          end
        
          location_str = row["Imprint Location#{num}"]
          raise "Unknown location: #{location_str}" unless /^(.+?):\s*(.+?)(?:,\s*(.+?))?\s*$/ === location_str
          dec.location = $1
          area = $2
          dec.limit = $3.to_i
          dec.limit = 1 if dec.limit == 0
        
          area = parse_dimension(area) if area
          dec.merge!(area) if area
          pd.decorations << dec
        end
      
      
        # Price/Cost
        pre = ''
        if !(late_date = row['Late Pricing Start Date']).blank? and
            (Date.today > Date.parse(late_date))
          pre = 'Late '
        end
        pricing = PricingDesc.new
        (1..10).each do |num|
          break if row["#{pre}Price#{num}"].blank?
          pricing.add(row["#{pre}Quantity#{num}"],
                      Float(row["#{pre}Price#{num}"]),
                      row["#{pre}Code#{num}"])
        end
        pricing.maxqty

        ltm_price = 40.0
        if /Less Than Minimum \$(\d{2,3}\.\d{2})/ === row['Optional Charges']
          ltm_price = Float($1)*0.8
        end
        pricing.ltm_if(ltm_price)


        pd.properties['material'] = row['Material'] unless row['Material'].blank?
        size = row['Sizes']
        pd.properties['dimension'] = parse_dimension(size) || size if size


        # Get all properties (usually color)
        props = (1..4).each_with_object({}) do |num, hash|
          name = row["Item Type#{num}"]
          next if name.empty?
          values = row["Item Colors#{num}"].split('|')
          hash[name] = values
        end
        
        color_keys = props.keys.find_all { |k| k.downcase.include?('color') }
        colors = props[color_key = color_keys.first] || []
        if color_keys.length == 1
          # Force to 'color' property if only one color key exists
          color_key = 'color'
          props = props.each_with_object({}) do |(k, v), hash|
            hash[k.downcase.include?('color') ? 'color' : k] = v
          end
        end
        
        variants = [{}]
        count = 1
        props.each do |name, values|
          count *= values.length
          break if count > 50

          variants = variants.collect do |prop|
            values.collect { |v| prop.merge(name => v) }
          end.flatten
        end
        

        color_image_map, color_num_map = match_colors(colors)

        if color_image_map.empty?
          pd.images = [ImageNodeFetch.new("#{@supplier_num}_Z.jpg",
                                          "http://norwood.com/images/products/zoom/#{@supplier_num}_Z.jpg")]
        else
          pd.images = color_image_map[nil]
        end

        pd.variants = variants.collect do |properties|
          num_w = (32 - @supplier_num.length-properties.length) / [properties.length,1].max
          num_suf = properties.keys.sort.collect { |k| '-' + properties[k].reverse[0...num_w].reverse.strip }.join
          VariantDesc.new(:supplier_num => @supplier_num + num_suf,
                          :pricing => pricing, :properties => properties,
                          :images => properties[color_key] && color_image_map[properties[color_key]])
        end
      end
    end
  end
end
