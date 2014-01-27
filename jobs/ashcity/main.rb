require '../generic_import'
require './import'

#import = AshCityXLS.new(['USD_ProductDataFile_SKU_save.csv', 'SPRING_USD_ProductDataFile_SKU.csv'])
import = AshCityXLS.new(['USD_ProductDataFile_(FULL)Styles.csv'])
import.run_parse_cache
import.run_transform
import.run_apply_cache

