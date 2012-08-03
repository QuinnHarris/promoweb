class ProductRecordMerge
  def initialize(unique_properties, common_properties, null_match = nil)
    @unique_properties, @common_properties, @null_match = unique_properties, common_properties, null_match
    @unique_hash = {}
    @unique_hash.default = []
    @common_hash = {}
  end
  attr_reader :id, :unique_properties, :common_properties, :null_match, :unique_hash, :common_hash

  def merge(id, object)
    if chash = common_hash[id]
      common_properties.each do |name|
        raise "Mismatch: #{id} #{name} #{chash[name].inspect} != #{object[name].inspect}" unless chash[name] == (object[name] === null_match ? nil : object[name])
      end
    else
      chash = common_properties.each_with_object({}) do |name, hash|
        hash[name] = object[name] unless object[name] === null_match
      end
      common_hash[id] = chash
    end

    uhash = unique_properties.each_with_object({}) do |name, hash|
      hash[name] = object[name]
    end
    raise "Duplicate: #{id} #{uhash.inspect} in #{unique_hash[id].inspect}" if unique_hash[id] && unique_hash[id].include?(uhash)
    unique_hash[id] += [uhash]
  end

  def each
    unique_hash.each do |id, uhash|
      chash = common_hash[id]
      yield id, uhash, chash
    end
  end
end

class SupplierPricing
  def initialize
    @prices = []
    @costs = []
  end

  def self.get
    sp = new
    yield sp
    sp.to_hash
  end

  # Duplicated in GenericImport Remove from there eventually
  def convert_pricecode(comp)
    comp = comp.upcase[0] if comp.is_a?(String)
    num = nil
    num = comp.ord - ?A.ord if comp.ord >= ?A.ord and comp.ord <= ?G.ord
    num = comp.ord - ?P.ord if comp.ord >= ?P.ord and comp.ord <= ?X.ord
    
    raise "Unknown PriceCode: #{comp}" unless num
    
    0.5 - (0.05 * num)
  end
  
  def add(qty, price, code = nil)
    base = { :fixed => Money.new(0),
      :minimum => Integer(qty) }
    price = Money.new(Float(price))
    @prices << base.merge(:marginal => price)

    if code
      discount = convert_pricecode(code)
      @costs << base.merge(:marginal => price * (1.0 - discount) )
    end
  end

private
  def ltm_common(charge, qty)
    @costs.unshift({ :fixed => Money.new(Float(charge)),
                    :marginal => @costs.first[:marginal],
                    :minimum => qty || @costs.first[:minimum]/2 })
  end
public

  def ltm(charge, qty = nil)
    raise "Can't apply less than minimum with no prices" if @costs.empty?
    qty = qty && Integer(qty)
    raise "qty >= first qty: #{qty} >= #{@costs.first[:minimum]}" if qty >= @costs.first[:minimum]
    ltm_common(charge, qty)
  end

  def ltm_if(charge, qty)
    raise "Can't apply less than minimum with no prices" if @costs.empty?
    qty = qty && Integer(qty)
    ltm_common(charge, qty) if qty < @costs.first[:minimum]
  end

  def maxqty(qty = nil)
    @costs << { :minimum => qty ? Integer(qty) : @costs.last[:minimum] * 2 } unless @costs.empty?
  end

  def to_hash
    { 'prices' => @prices, 'costs' => @costs }
  end
end


class LogomarkXLS < GenericImport
  def initialize
    time = Time.now - 1.day
    #%w(Data Data_Portfolio CloseoutsData ECOData)
    @src_files = %w(Data).collect do |name|
      WebFetch.new("http://www.logomark.com/Media/DistributorResources/Logomark#{name}.xls").
        get_path(time)
    end
    super 'Logomark'
  end

  def parse_products
    unique_columns = %w(SKU Item\ Color)
    common_columns = %w(Product\ Line Name Description Features Finish\ /\ Material IsAdvantage24 Categories Item\ Size Decoration\ Height Decoration\ Width LessThanMin1Qty LessThanMin1Charge End\ Column\ Price Box\ Weight Quantity\ Per\ Box Box\ Length Production\ Time) + (1..6).collect { |i| %w(Qty Price Code).collect { |s| "PricePoint#{i}#{s}" } }.flatten

    @src_files.each do |file|
      product_merge = ProductRecordMerge.new(unique_columns, common_columns)

      puts "Processing: #{file}"
      ss = Spreadsheet.open(file)
      ws = ss.worksheet(0)
      ws.use_header
      ws.each(1) do |row|
        next if row['SKU'].blank?
        raise "Unkown SKU: #{row['SKU'].inspect}" unless /^([A-Z]+\d*)([A-Z]*(?:-[\w-]+)?)$/ === row['SKU']
        begin
          product_merge.merge($1, row)
        rescue Exception => e
          puts "RESCUE: #{e}"
        end
      end

      product_merge.each do |supplier_num, unique, common|
        product_data = {
          'supplier_num' => supplier_num,
          'name' => "#{common['Name'] || supplier_num} #{common['Description']}",
          'description' => common['Features'] || '',
          'supplier_categories' => (common['Categories'] || '').split(',').collect { |c| [c.strip] },
          'package_units' => Integer(common['Quantity Per Box']),
          'package_weight' => Float(common['Box Weight'])
        }

        unless /^(\d+)-(\d+) Working ((?:Days)|(?:Weeks))$/ === common['Production Time']
          raise "Unkown Production Time: #{supplier_num} #{common['Production Time']}"
        end
        multiplier = ($3 == 'Days') ? 1 : 5
        product_data.merge!('lead_time_normal_min' => Integer($1) * multiplier,
                            'lead_time_normal_max' => Integer($2) * multiplier)
        product_data['lead_time_rush'] = 1 if common['IsAdvantage24'] == 'YES'

        common_properties = { 'material' => common['Finish / Material'],
          'size' => common['Item Size'] && parse_volume(common['Item Size'])
        }


        common_variant = SupplierPricing.get do |pricing|
          (1..6).each do |i|
            qty = common["PricePoint#{i}Qty"]
            break if qty.blank? or qty == '0'
            pricing.add(qty, common["PricePoint#{i}Price"], common["PricePoint#{i}Code"])
          end
          pricing.maxqty
          unless common['LessThanMin1Qty'] == 0
            pricing.ltm_if(common['LessThanMin1Charge'], common['LessThanMin1Qty'])
          end
        end


        decorations = [{
                         'technique' => 'None',
                         'location' => ''
                       }]
        product_data['decorations'] = decorations


        product_data['images'] = [ImageNodeFetch.new("Group/#{supplier_num}.jpg",
                                                     "http://www.logomark.com/Image/Group/Group800/#{supplier_num}.jpg")]

        product_data['variants'] = unique.collect do |uniq|
          { 'supplier_num' => variant_num = uniq['SKU'],
            'properties' => { 'color' => uniq['Item Color'] },
            'images' => [ImageNodeFetch.new("Model/#{variant_num}.jpg",
                                            "http://www.logomark.com/Image/Model/Model800/#{variant_num}.jpg")]
          }.merge(common_variant)
        end

        add_product(product_data)
      end
    end
  end
end
