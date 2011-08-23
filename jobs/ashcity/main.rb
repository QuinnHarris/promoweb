require '../generic_import'
require './import'

import = AshCityXML.new('AshCity/US_ProductDataFile_Styles.xml')
import.run_parse_cache
import.run_transform
import.run_apply_cache

