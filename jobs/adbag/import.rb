# ToDO
# Quantity on decoration pricing

class AdbagProdXLS < GenericImport
  def initialize
    @src_file = File.join(JOBS_DATA_ROOT, '2012AABCATALOG.xlsx')
    super 'American Ad Bag'
  end


  def fetch_parse?
    # if File.exists?(@src_file) and
    #     File.mtime(@src_file) >= (Time.now - 7.day)
    #   puts "File Fetched today"
    #   return false
    # end
    
    # puts "Starting Fetch"
    
    # agent = Mechanize.new
    # page = agent.get('http://crownprod.com/includes/productdata.php')
    # form = page.forms.first
    # form.action = '/' + form.action
    # page = agent.submit(form)
    
    # page.save_as @src_file
    
    # puts "Fetched"
    # true
  end
  def parse_products
    wksheets = RubyXL::Parser.parse(@src_file)
    ws = wksheets[0]
    @dup_product = []
    ws.rows.each_with_index do |row,index|
      @dup_product.include?(row["PRODUCT NAME"]) ? next : @dup_product << row["PRODUCT NAME"] 
      ProductDesc.apply(self) do |pd|
        pd.supplier_num = row["ITEMNO"]
        pd.name = row["PRODUCT NAME"]
        pd.description = row["DESCRIPTION 1"]+ " " + row["DESCRIPTION 2"]
        pd.supplier_categories = [[row["CATEGORY"]]]
        pd.properties['dimension'] = parse_dimension(row["PRODUCT DIMENSIONS"])
        pd.package.weight =  Float(row["PACK WEIGHT"].gsub!("LBS",""))
       # pd.package.units =  parse_dimension(row["PACK SIZE"])
        pd.package.height =  row["PACK HEIGHT"].to_f 
        pd.package.length = row["PACK LENGTH"].to_i
        pd.package.width = row["PACK WIDTH"].to_i
        
        /^(?<min>\d)\s*(-\s*(?<max>\d)\s*)? WORKING DAYS$/ =~ row["LEAD TIME"].to_s
        pd.lead_time.normal_min = min
        pd.lead_time.normal_max = max || min

        colors = []
        colors << row["COLOR"]
        begin
         index+=1
         next_row = ws.next_row(index)
         colors << next_row["COLOR"] unless colors.include?(next_row["COLOR"])
        end while next_row["ITEMNO"] == row["ITEMNO"]  
        pricing = []
        (1..6).each do |n|
           pricing << [row["QTY BREAK #{n}"],row["SELL/COST #{n}"]]
        end
        debugger


        pd.tags = []

      end
    end  
  end
end
