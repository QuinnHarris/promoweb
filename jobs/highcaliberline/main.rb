require '../generic_import'
require './import'

import = HighCaliberLine.new('03-06-2013')
import.set_standard_colors
import.run_parse_cache
import.run_transform 
import.run_apply_cache
