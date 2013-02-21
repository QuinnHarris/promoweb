require '../generic_import'
require './import'

import = AshCityXLS.new(['USD_ProductDataFile_SKU.csv', 'SPRING_USD_ProductDataFile_SKU.csv'])
import.run_parse_cache
import.run_transform
import.run_apply_cache

