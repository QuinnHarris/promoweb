require '../generic_import'
require './import'

import = HitPromoCSV.new('2012')
import.run_parse #_cache
import.run_transform
import.run_apply_cache
