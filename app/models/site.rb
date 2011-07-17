class Site < ActiveRecord::Base
  class << self
    attr_accessor :url
    attr_accessor :sql_order
  end
  def url; self.class.url; end
  def sql_order; self.class.sql_order; end
  
  has_many :pages
  
  def product_page?(path); true; end
  
  @@price_regex = /(?:(\d*)\.(\d{2}))|(?:(\d{2})&#162;)/
  def table_canidates(doc)
    doc.search("//table").find_all do |table|
      next false unless table.search("//table").empty?
      elems = table.search("th|td").collect { |t| t.inner_html }
      next false unless elems.length >= 4
      next false unless elems.find { |t| /pric/i =~ t }
      elems.find { |t| @@price_regex =~ t }
    end
  end
  
  def table_translate(table)
    max = 0
    groups = []
    table.search("tr/th|tr/td").each do |td|
      #(&[^;]+;)|
      str = td.inner_html.gsub(/(<script>[^<]+<\/script>)|(<[^>]+>)|(&nbsp;)|\$|(ea\.)/, '').strip
      next if str.empty?
      if group = groups.find { |g| g.first == td.parent}
        group[1] += [str]
      else
        groups << [td.parent, [str]]
      end
    end
    groups.collect do |parent, list|
      max = list.length if max < list.length
      list
    end.find_all { |r| r.length == max }
  end
  
#  def table_translate(table)
#    max = 0
#    table.search("tr").collect do |tr|
#      row = tr.search("th|td").collect do |td|
#        str = td.inner_html.gsub(/(<script>[^<]+<\/script>)|(<[^>]+>)|(&[^;]+;)|\$|(ea\.)/, '').strip
#        next nil if str.empty?
#        str
#      end.compact
#      max = row.length if max < row.length
#      row
#    end.find_all { |r| r.length == max }
#  end
  
  
  def process_quantities(data)
    [data.first.first, data.first[1..-1].collect do |r|
#      str = r.gsub(/,|\+|( .*)/,'')
#      i = str.to_i
#      return nil unless i.to_s == str
      return nil unless /^(\d+)/ =~ r
      $1.to_i
    end]
  end
  
  def process_prices(data, qtys)
    puts "Process Prices: #{data.inspect} #{qtys.inspect}"
    data[1..-1].collect do |row|
      p = row[1..-1].collect do |r|
        all, dollars, centsA, centsB = @@price_regex.match(r).to_a
        next nil unless all
        cents = centsA || centsB
        dollars.to_i * 100 + cents.to_i
      end
      return false if p.length != qtys.length
      [row.first, p]
    end
  end
  
  def select_prices(list)
    list.sort { |l, r| l.last.inject(0) { |s, i| s+=i; s } <=> r.last.inject(0) { |s, i| s+=i; s } }.first
  end
  
  def process_table(data)
    puts " Data: #{data.inspect}"
    qty_name, qty_nums = process_quantities(data)
    puts " Quantities: #{qty_name} : #{qty_nums.inspect}"
    prc_name, prc_nums = select_prices(process_prices(data, qty_nums))
    puts " Prices: #{prc_name} : #{prc_nums.inspect}"
    qty_nums.zip(prc_nums).collect do |min, price|
      { :minimum => min,
        :fixed => Money.new(0),
        :marginal => Money.new(price) #might be broken with 1000 money
      }
    end
  end
  
  def canidate_products(doc)
    query_str = query_string(doc).gsub(/"/,'')
    puts " Query: #{query_str.inspect}"
    i = 0
    Product.find_by_tsearch(query_str).collect { |p| i += 1; [1.0/i.to_f, p] }
  end
  
  def title(doc)
    doc.search("//title").inner_html.strip
  end
  
  def include_uri?(uri); true; end
  def normalize_uri(request_uri);
    request_uri.split(/\/+/).inject([]) { |l, e| e == '..' ? l.pop : l << e; l }.join('/') + ((request_uri[-1] == '/'[0]) ? '/' : '')
  end
end



# Site Class Definitions
class PromoPeddler < Site
  self.url = 'www.promopeddler.com'
  def product_page?(path)
    /^[^\/]+\/[^\.]+\.htm/ =~ path
  end
  def query_string(doc)
    title = doc.search("//title").inner_html.strip
    /^[^\(-]+/.match(title)[0]
  end
end

# Not completative 2008-12-16
class RushImprint < Site
  self.url = 'www.rushimprint.com'
  def product_page?(path)
    /^view_product.php\?/ =~ path
  end
  
  def include_uri?(request_uri)
    not %w(reviews_write blog estimate_freight).find { |s| request_uri.include?(s) }
  end
  
  def normalize_uri(request_uri)
    request_uri = super request_uri
    case request_uri
      when /^view_product\.php\?(?:.+?&)?productID=(\d+)/
        "view_product.php?productID=#{$1}"
    else
      request_uri
    end
  end
end


class Epromos < Site
  self.url = 'www.epromos.com'
  self.sql_order = "request_uri LIKE 'product%' DESC"
  def product_page?(path)
    /^product\// =~ path
  end
  def query_string(doc)
    title = doc.search("//title").inner_html.strip
    /^[^\(-]+/.match(title)[0]
  end
  
  def include_uri?(request_uri)
    return false if /^browse\/(N.+-)+(\d+-?)+\.html$/ === request_uri
    not %w(ProductIndex AboutePromos CustomerService educationCenter emailfriend.do order.do quote.do OrderPipeline).find { |s| request_uri.include?(s) }
  end
end

class Gimmees < Site
  self.url = 'www.gimmees.com'
  def product_page?(path)
    /^detail/ =~ path
  end
  
  def canidate_products(doc)
    return [] unless sku_node = doc.search("//div/table/tr/td/p/table/tr/td[@class='smalltext']").first
    sku = sku_node.inner_html
    prod = nil
    puts "SKU: #{sku}"
    rules = [
      [/^GEML(\d+)/, 'Gemline'],
      [/^LEED([\d-]+)/, 'Leeds'],
      [/^PRIM([\w\d-]+)/, 'PrimeLine']
    ]
    
    rules.find do |regex, name|
      next unless regex =~ sku
      puts "#{name} Canidate"
      prod = Product.find(:first,
        :conditions => ["suppliers.name = ? AND products.supplier_num = ?", name, $1],
        :include => :supplier)
      puts "Found #{name}" if prod
    end

    return [[200.0, prod]] if prod
    []
  end
  
  def query_string(doc)
    title = doc.search("//title").inner_html.strip
    /^[^:]+/.match(title)[0]
  end
  
  def include_uri?(request_uri)
    return false if /page~-\d+\.asp$/ === request_uri
    not %w(articles cart1~pnum~ quote~pnum~ wishlist~wish~ blog asp/index.asp).find { |s| request_uri.include?(s) }
  end
  
  def normalize_uri(request_uri)
    request_uri = super request_uri
    case request_uri
      when /^detail~pNum~(\d+)~pcategory~\d+~psubcategory~\d*\.asp/i
        "detail~pNum~#{$1}.asp"
    else
      request_uri
    end
  end
end

class QualityLogoProducts < Site
  self.url = 'www.qualitylogoproducts.com'
  self.sql_order = "request_uri LIKE '%/%.htm' DESC"

  def product_page?(path)
    return nil if path.index('show-all')
    /^(.+)-(.+)\// =~ path
  end

  def include_uri?(request_uri)
    not [/^((order-sample\/index)|(product-reviews\/((reviewHelpful)|(writeReview)))|(quote)|(sale-notification\/index)|(tellfriend))\.cfm/, /^printer-friendly\//].find { |re| re === request_uri }
  end

  def title(doc)
    doc.search("//h1").inner_html.gsub(/<.+?\/>/, '').strip
  end

  
  # Duplicated from generic_import
  @@volume_reg = /^ *(\d{1,2}(?:\.\d{1,2})?[ -]?)?(?:(\d{1,2})\/(\d{1,2}))? ?"? ?([lwhd])?/i
  def parse_volume(str)
    res = {}
    list = %w(l w h)
    str.split('x').collect do |comp|
      all, a, n, d, dim = @@volume_reg.match(comp).to_a
      dim = list.shift if res.has_key?(dim) or !dim
#      return nil if res.has_key?(dim)
      res[dim] = (a ? a.to_f : 0.0) + (d ? (n.to_f/d.to_f) : 0.0)
      list.delete_if { |x| x == dim }
    end
#    return nil unless res.size == 3
    res
  end

  
  def match_product(doc, product)
    our_dim = product.properties_get['dimension']
    our_dim = our_dim.first.split(/\s*x\s*/).collect { |s| s.to_f }.sort if our_dim
    thier_dim = doc.search("//tr/td[@class='attName'][text() = 'Dimensions:']").first
    thier_dim = parse_volume(thier_dim.next_sibling.inner_html.gsub('&quot;','"')).values.sort if thier_dim
    
    match = (our_dim && our_dim == thier_dim)
    puts " Dims: #{our_dim == thier_dim} : #{our_dim.inspect} == #{thier_dim.inspect}"
    unless match
      our_desc = product.description.gsub(/(\W|[^[:print:]])+/, ' ').strip.downcase
      thier_desc = doc.search("//td[@id='prodDescription']").first
      return nil unless thier_desc
      thier_desc = thier_desc.inner_html.gsub(/(\W|[^[:print:]])+/, ' ').strip.downcase if thier_desc

      require 'amatch'
      match_len = Amatch::LongestSubstring.new(our_desc).match(thier_desc)
      #        match = (our_desc.length < thier_desc.length) ? thier_desc.include?(our_desc) : our_desc.include?(thier_desc)
      match = (match_len > 24) #&& (match_len > [our_desc.length, thier_desc.length].min * 0.4)
      puts "Desc: #{match} #{match_len} #{our_desc.inspect} #{thier_desc.inspect}"
    end

    match
  end


  def canidate_products(doc)
    t = title(doc)
    return [] unless t and t.length > 6

    if product = Product.find_by_name(t)
      match = match_product(doc, product)
      return [[match ? 200 : 100, product]]
    end

    products = Product.find_by_tsearch(t.gsub(/\s+&\w+;\s+/, ' '))
    products.each do |product|
      match = match_product(doc, product)
      return [[150, product]] if match
    end

    return []
  end
end

class Imprint < Site
  self.url = 'www.4imprint.com'
  self.sql_order = "request_uri LIKE 'exec/detail%' DESC"
  
  def product_page?(path)
    /^exec\/detail\/~ca[^\/]+\.htm$/ =~ path
  end
  
  def title(doc)
    return nil unless /^(.+?) \(.+\)/ =~ doc.search("//title").inner_html.strip
    $1.strip
  end
  
  @@synonyms = {
    'tag' => 'chain',
    'portfolio' => 'laptop&bag'
  }
  
  def canidate_products(doc)
    return [] unless site_title = title(doc)
    case site_title
      when /^Stress Ball - (.+)$/
        site_title = "#{$1} Stress Reliever"
    end
    site_title_a = site_title.scan(/[\d\w]+/)
    site_title_s = site_title_a.join(' ')
    site_title_first, site_title_second = site_title.split(' - ')
    site_title_first = site_title_first.scan(/[\d\w]+/).join(' ')
    site_title_second = site_title_second.scan(/[\d\w]+/).join(' ') if site_title_second

#    colors = doc.search("//div[@class='PD_ColorListView']//td/div/span/text()").collect { |s| s.to_s.strip }
    
    puts " Product: #{site_title_first} : #{site_title_second}"
    product = Product.find_by_name(site_title_first)
    product = Product.find_by_name(site_title_first + ' ' + site_title_second) unless product or !site_title_second
    if product
 #     prod_colors = product.variants.find(:all, :include => :properties, :conditions => "properties.name = 'color'").collect { |v| v.properties.collect { |p| p.value } }.flatten    
      puts "  * Found Product : #{product.name} (#{product.id})"
      return [[100.0, product]] #if (prod_colors - colors).empty?
    end
    
    query = site_title_first.scan(/\w+/).collect do |word|
      if syn = @@synonyms[word]
        next '(' + ([word] + [syn]).flatten.join('|') + ')'
      end
      word
    end.join('&')
    puts " Search: #{query}"
    products = Product.find_by_tsearch(query, {}, :fix_query => false)
    canidates = []
    products.each do |prod|
      prod_title_a = prod.name.downcase.scan(/[\d\w]+/)
      prod_title_s = prod_title_a.join(' ').downcase
      (2..site_title_a.length).to_a.reverse.find do |l|
        (0..(site_title_a.length-l)).find do |i|
          sub_str = site_title_a.slice(i, l).join(' ')
          if prod_title_s.index(sub_str)
            canidates << [[site_title_a.length, prod_title_a.length].min, l, prod]
          end
        end
      end
    end
    return [] if canidates.empty?
    puts " Canidates: #{canidates.inspect}"
    
    canidates.sort! do |(l_max, l_len, l_prod),(r_max, r_len, r_prod)|
      next r_len <=> l_len unless r_len == l_len
      next l_max <=> r_max unless l_max == r_max
      r_prod.name.length <=> l_prod.name.length
    end
    
    canidates.collect do |max, length, product|
      [length * 99.0 / max, product]
    end
  end
  
  def include_uri?(request_uri)
    return false if /^products\/searchmall\.aspx/ === request_uri and !request_uri.include?('mid=')
    not %w(rss/ attachments/ _customerrorpages/ marketing/newsletters exec/print products/suspendedproduct.aspx search/asearch.aspx search/bsearch.aspx exec/keywordsearch fromproductgroup related+items addclick.aspx promotional_product_videos reviews meet_the_reviewer moreimages.aspx imageserver zoom.aspx productrelatedviews.asp newsletterarchive privacy webresource).find { |s| request_uri.downcase.include?(s) }
  end
  
  def normalize_uri(request_uri)
    request_uri = super request_uri
    case request_uri
      when /^(?:.+?\/)?exec\/detail\/.+?\/(~CA.+?\.htm)$/i,
           /^Promotional\+products\/~sku.+?\/(~CA.+?\.htm)/i
        "exec/detail/#{$1.downcase}"
      
      when /^.+?\/exec\/(.+)$/
        "exec/#{$1.downcase}"
        
      when /exec\/product-group\/(?:.+?\/)?grp(\d+)\//i, /^products\/groupview\.aspx\?group=(\d+)/i
        "products/groupview.aspx?group=#{$1}&ps=10000"

      when /^(products\/(?:(?:productsonsale)|(?:price-drops)|(?:newproducts)))\.aspx/i, /^(whatshot\/(?:(?:hotproducts)|(?:hotsaleitems)))\.aspx/i
        "#{$1.downcase}.aspx?ps=10000"
        
      when /^products\/boutiquestore.aspx?.*CSID=(\d+)/i, /^exec\/boutique\/~bsid(\d+)/i
        "products/boutiquestore.aspx?CSID=#{$1}&ps=10000"
        
      when /^([^\/]+)\/default.asp\?/i
        "#{$1.downcase}/"
        
      when /^prodgroups\/grouptopitems\.aspx\?.*grpid=(\d+)/i
        "prodgroups/grouptopitems.aspx?grpid=#{$1}"
        
      when /^products\/searchmall\.aspx\?.*mid=(\d+).*pg=(\d+)/
        "products/searchmall.aspx?mid=#{$1}&pg=#{$2}&ps=10000"
        
      else
        request_uri.downcase.gsub(/(amp;)+/,'amp;')
    end
  end
end

class Branders < Site
  self.url = 'www.branders.com'
  self.sql_order = "request_uri LIKE 'product%' DESC"
  
  def product_page?(path)
    /^product\// =~ path
  end
  
  def include_uri?(request_uri)
    not %w(pages/product_zoom.jsf catalog/product_detail.jsp ds.jsp? referrertrack comparisons account).find { |s| request_uri.include?(s) }
  end
  
  def normalize_uri(request_uri)
    request_uri = super request_uri
    case request_uri
      when /^product\/.+?\?prdid=(\d+)/, /^s\/.+?-.+?---.+?(\d{5,6}).html$/
        "product/?prdid=#{$1}"
      when /^subcat\/.+?\?fdrid=(\d+)/
        "subcat/?fdrid=#{$1}"
      when /^(.+?);jsessionid=\w+!-\d+(.*)$/
        $1 + $2
      else
        request_uri
    end
  end
  
  def title(doc)
    doc.search("//h2/span[@class='pagetitle']").inner_html.strip
  end
  
  def canidate_products(doc)
    title = title(doc)
    return [] if title.empty?
    all, category, name, tail = /^(?:(.+?)\W+\-\W+)?([^\,\(]+)(.*)$/.match(title).to_a

    puts " Name: #{name.inspect}"
    product = Product.find_by_name(name)
    if !product and category
      name += ' ' + (category.split(/\W+/) - name.split(/\W+/)).join(' ') if category
      puts " Name: #{name.inspect}"
      product = Product.find_by_name(name)
    end

    if product
      puts "  * Found Product : #{product.name} (#{product.id})"
      return [[100.0, product]]
    end
    
    []
  end
end

class PinnaclePromotions < Site
  self.url = 'www.pinnaclepromotions.com'
  self.sql_order = "request_uri LIKE 'product%' DESC"
  
  def product_page?(path)
    /^product\// =~ path
  end
  
  def include_uri?(request_uri)
    not %w(add_to_workspace modules workspace production_time.php ajaxstarrater pricematch users).find { |s| request_uri.include?(s) }
  end
  
  def canidate_products(doc)
    script = doc.search("//div[@id='mainBdy']/script").inner_html
    return [] if script.empty?
    attributes = script.scan(/"(.+?)":"(.+?)"/).inject({}) { |h, e| h[e[0]] = e[1]; h }
    return [] unless manufacturer = attributes['manufacturer']
    return [] unless prod_number = attributes['prod_number']
    
    case manufacturer
      when "Gemline"
        prod_number = /[^-]+/.match(prod_number)[0]
      when "Prime_Line"
        manufacturer = "PrimeLine"
    end
    
    supplier = Supplier.find_by_name(manufacturer)
    unless supplier
      puts "Couldn't find Supplier: #{manufacturer}" unless supplier
      return []
    end

    prod = supplier.products.find(:first,
      :conditions => ["supplier_num = ? OR id IN (SELECT product_id FROM variants WHERE supplier_num = ?)",
        prod_number, prod_number]
    )
    unless prod
      puts "Counldn't find Product: #{prod_number} for #{manufacturer}"
      return []
    end
    
    [[200, prod]]
  end

  def normalize_uri(request_uri)
    request_uri = super request_uri
    case request_uri
      when /^product\/.+?\/\d+?\/(\d+)\/$/
        "product/_/0/#{$1}/"

      when /^category\/(.+?\/\d+?)\/(?:(?:\d+?)|(?:all))\//
        "category/#{$1}/all/?be=1"

      when /^categories\/(.+?\/\d+?)\//
        "categories/#{$1}/"

      else
        request_uri
    end
  end
end

class SuperiorPromos < Site
  self.url = 'www.superiorpromos.com'
  def product_page?(path)
    /^viewProduct.html\?/ =~ path
  end
  
  def include_uri?(request_uri)
    not %w(addProductWishlist_action.html bannerClick.html b_orderingWizard_1.html login.html newAccount.html).find { |s| request_uri.include?(s) }
  end
  
  def normalize_uri(request_uri)
    request_uri = super request_uri
    case request_uri
      when /^viewProduct\.html\?id=(\d+)/
        "viewProduct.html?id=#{$1}"
      else
        request_uri
    end
  end
end

class InkHead < Site
  self.url = 'www.inkhead.com'
  def product_page?(path)
    /\/(.+)\// =~ path
  end
  
  def include_uri?(request_uri)
    not %w(Secure).find { |s| request_uri.include?(s) }
  end
  
  def normalize_uri(request_uri)
    request_uri = super request_uri
    case request_uri
      when /^(.+?)\?/
        $1
      else
        request_uri
    end
  end
end

class Motivators < Site
  self.url = 'www.motivators.com'
  self.sql_order = "request_uri LIKE 'Promotional-Custom%' DESC"
  
  alias_method :doc_title, :title
  def title(doc)
    return nil unless /^(.+?)<br \/>/ =~ doc.search("//h2").inner_html.strip
    $1.strip.gsub(/[^[:print:]]/,'')
  end
  
  def canidate_products(doc)
    title = doc_title(doc)
    return [] unless /^(.+?),.+?,\s*([\w-]+)\s*$/ =~ title.gsub(/[^[:print:]]/,'')
    name, number = $1, $2
    puts " Name:  #{name}  Number: #{number}"
    
    rules = [
      [/^Gemline\s*(.+)$/, nil, 'Gemline'],
      [/^Leeds\s*(.+)$/, nil, 'Leeds'],
      [nil, /^PL-\d+$/, 'PrimeLine'],
    ]
    
    prod = nil
    rules.find do |namex, numx, supplier|
      if (namex and namex =~ name) or
         (numx and numx =~ number)
        prod = Product.find(:first,
          :conditions => ["suppliers.name = ? AND (products.supplier_num = ? or variants.supplier_num = ?)", supplier, number, number],
          :include => [:supplier, :variants])
        puts " ****** !!!! NOT FOUND Name: #{name} Canidate: #{number} of #{supplier}" unless prod
        true
      end
    end
    puts " * Found #{name}" if prod
    
    unless prod
      prod = Product.find(:first, :conditions => ["lower(name) = ? AND supplier_num = ?", name.downcase, number])
      puts " * Found Generic: #{name} #{number} #{prod.supplier.name}" if prod
    end

    return [[200.0, prod]] if prod
    []
#    super doc
  end
  
  def product_page?(path)
    /^Promotional-Custom-[\w-]+-\d+\.html$/ =~ path
  end
  
  def include_uri?(request_uri)
    not [/^(?:(?:blogs)|(?:forum)|(?:podcasts)|(?:press)|(?:profiles))\//i, /^ratingtooltip\.asp/i, /^\w+-Promotional-Advertising-Products-\d+\.html/].find { |re| re === request_uri }
  end

  @@product_regexp = Regexp.new('^Promotional-Custom-(?:' + 
    ["Gemline", "Leeds", "Prime", "Wenger", "UltraClub", "Sheaffer", "CutterandBuck", "Ping", "Bic", "AndrewPhilipsCollection", "PortAuthority", "HarvardSquare", "Bulletline", "HighSierra", "CharlesRiverApparel", "Bella", "AliciaKlein", "CaseLogic", "CallawayGolf", "Maglite", "Toppers", "Hanes", "DLX", "Anvil", "DevonandJones", "LeccePen", "Gemaco", "Balmain", "BlueGeneration", "Laguiole", "DayTimer", "Royce", "Yupoong", "PostIt", "Papermate", "Dockers", "Sharpie", "Prodir", "Maxfli", "Nike", "TopFlite", "Wilson", "Titleist", "Coleman", "AdvaLite", "AtchisonbyBic", "Expo", "Uniball", "RBag", "Ogio", "Cross", "BerneApparel", "ColumbiaSportswear", "Stanley", "GildanActivewear", "Parker", "Tumi", "LeemanDesigns", "Jerzees", "Champion", "FruitOfTheLoom", "Waterman", "Pentel", "AmericanApparel", "KarimRashid", "Garrity", "Clique", "SwissArmy", "Adidas", "Slazenger", "Dickies", "EcoSmartOwl", "Harriton", "Rollabind", "Pinnacle", "Vantage", "Hazel", "Duracell", "Zippo", "Aladdin", "Pilot", "DistrictThreads", "RedHouse", "PortandCompany", "Sportline", "Everlast", "Melitta", "GeorgeForeman", "IZOD", "BillBlassPremium", "CrossCreek"].collect { |s| "(?:#{s})" }.join('|') + ')(\w+-\d+\.html)$')
  
  def normalize_uri(request_uri)
    request_uri = super request_uri
    case request_uri
      when /^(?:(?:(?:Cheap)|(?:C)|(?:E)|(?:NE)|(?:N)|(?:NW)|(?:SE)|(?:S)|(?:SW)|(?:W))-)?Promotional-[\w-]+-(\d+)-(\d+)\.html$/
        "promotional-products/listproductsbysubcatid.asp?category_id=#{$1}&subcategory_id=#{$2}&nitems=1000"
      when @@product_regexp
        "Promotional-Custom-#{$1}"
      else
        request_uri
    end
  end
end


#class PromosOnTime < Site
#  self.url = 'www.promosontime.com'
#  def product_page?(path)
#    /^get_item_/ =~ path
#  end
#end

#class EcoPromosOnline < Site
#  self.url = 'ecopromosonline.com'
#  def product_page?(path)
#    /p-\d+\.html/ =~ path
#  end
#end

#class GoPromos < Site
#  self.url = 'www.gopromos.com'
#  def product_page?(path)
#    /ProductDetail/ =~ path
#  end
#end

#class EmpirePromos < Site
#  self.url = 'www.empirepromos.com'
#  
#  def product_page?(path)
#    /^items\// =~ path
#  end
#end
