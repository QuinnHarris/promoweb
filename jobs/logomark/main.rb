require '../generic_import'
require './import'

import = LogomarkXLS.new
import.run_parse #_cache
import.run_transform
import.run_apply_cache
