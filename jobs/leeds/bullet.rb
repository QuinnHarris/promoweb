require '../generic_import'
require './import'

class BulletXLS < PolyXLS
  def initialize
    @src_urls = ['http://www.bulletline.com/services/downloads/excel/WebDecorationMethodByItem.xls']
    @src_urls << 'http://www.bulletline.com/services/downloads/excel/Catalog.xls'
    @image_url = 'images.bulletline.com'
    super "Bullet Line", :prune_colors => true
  end
end


import = BulletXLS.new
import.run_all
