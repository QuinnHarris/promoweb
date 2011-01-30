require '../generic_import'
require 'import'
#require 'transform'

puts "Stating Fetch"
# USDGusto
catalog_files = %w(USDcatalog USDMemorycatalog).collect do |name|
  WebFetch.new("http://media.leedsworld.com/ms/?/excel/#{name}/EN").get_path(Time.now-24*60*60)
end

decoration_file = WebFetch.new('http://media.leedsworld.com/ms/?/excel/WebDocrationMethodByItem/EN').get_path(Time.now-24*60*60)

#["../data/catalog.xls", "../data/USDGusto.xls", "../data/US Memorycatalog.xls"]
#"../data/WebDecorationMethodByItem.xls"

import = LeedsXLS.new(catalog_files, decoration_file)
import.run_parse_cache
import.run_transform
import.run_apply_cache
