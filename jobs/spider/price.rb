require 'sites'

require 'hpricot'
Hpricot.buffer_size = 262144

$file_cache = FileCache.new('spider')

PageProduct.find(:all,
  :conditions => "correct OR score > 100.0",
  :include => [:page, :product]
  ).each do |pp|
  
  page_record = pp.page
  puts "URL: #{page_record.url}"
  next unless res = $file_cache.get(URI.parse(page_record.url))
  next unless doc = Hpricot(res.body)
  title = page_record.site.title(doc)
  puts " Title: #{title}"
  
  site_record = page_record.site
  prices = nil
  table_canidates = site_record.table_canidates(doc)
  table_canidates.each do |table|
    data = site_record.table_translate(table)
#        puts "Table: #{table.inspect} => #{data.inspect}"

#        begin
      prices = site_record.process_table(data)
#        rescue
#          prices = site_record.process_table(data.transpose)
#        end
    break unless prices.empty?
  end

  puts "Final: #{prices.inspect}"
  begin
    source_record = PriceSource.get_by_name(page_record.site.url)
    log = pp.product.set_prices(source_record, [[prices, pp.product.variants]])
    puts log
  rescue
    puts "FAIL!!!"
  end
end