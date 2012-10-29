require '../generic_import'
require './import'

class LeedsXLS < PolyXLS
  def initialize
    @src_urls = ['http://media.leedsworld.com/msfiles/downloads/WebDecorationMethodByItem.xls']
    @src_urls += %w(USDcatalog USDMemorycatalog).collect do |name|
      "http://media.leedsworld.com/ms/?/excel/#{name}/EN"
    end
    @image_url = 'images.leedsworld.com'
    super "Leeds"
  end
end

import = LeedsXLS.new
import.run_all
