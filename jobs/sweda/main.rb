require '../generic_import'
require './import'

import = SwedaXML.new
import.run_parse_cache
import.run_transform
import.run_apply_cache
