require '../generic_import'
require './import'

import = AshCityXLS.new(['US_ProductDataFile_SKUs.xls', 'SPRING 2012_USA_ProductDataFile_SKUs.xls'])
import.run_parse_cache
import.run_transform
import.run_apply_cache

