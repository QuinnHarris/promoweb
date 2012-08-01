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

class LogomarkXLS < GenericImport
  def initialize
    time = Time.now - 1.day
    @src_files = %w(Data Data_Portfolio CloseoutsData ECOData).collect do |name|
      WebFetch.new("http://www.logomark.com/Media/DistributorResources/Logomark#{name}.xls").
        get_path(time)
    end
    super 'Logomark'
  end

  def parse_products
    unique_columns = %w(SKU Item\ Color)
    common_columns = %w(Product\ Line Name Description Features Finish\ /\ Material IsAdvantage24 Categories Item\ Size Decoration\ Height Decoration\ Width LessThanMin1Qty LessThanMin1Charge End\ Column\ Price Box\ Weight Quantity\ Per\ Box Box\ Length) + (1..6).collect { |i| %w(Qty Price Code).collect { |s| "PricePoint#{i}#{s}" } }.flatten

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
          'description' => common['Features'],
          'supplier_categories' => common['Categories']
        }


#        add_product(product_data)
      end
    end
  end
end
