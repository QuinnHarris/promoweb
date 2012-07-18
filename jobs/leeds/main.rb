require '../generic_import'
require './import'

class LeedsXLS < PolyXLS
  def initialize
    @prod_files = %w(USDcatalog USDMemorycatalog).collect do |name|
      "http://media.leedsworld.com/ms/?/excel/#{name}/EN"
    end
    @dec_file = 'http://media.leedsworld.com/msfiles/downloads/WebDecorationMethodByItem.xls'
    @image_url = 'images.leedsworld.com'
    super "Leeds"
  end
end

import = LeedsXLS.new
import.run_parse_cache
import.run_transform
import.run_apply_cache
