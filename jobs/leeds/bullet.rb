require '../generic_import'
require './import'

class BulletXLS < PolyXLS
  def initialize
    @prod_files = 'http://www.bulletline.com/services/downloads/excel/Catalog.xls'
    @dec_file = 'http://www.bulletline.com/services/downloads/excel/WebDecorationMethodByItem.xls'
    @image_url = 'images.bulletline.com'
    super "Bullet Line"
  end
end


import = BulletXLS.new
import.run_parse_cache
import.run_transform
import.run_apply_cache
