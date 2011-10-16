require '../generic_import'
require './import'

import = BulletLine.new
import.set_standard_colors
import.run_parse_cache
import.run_transform
import.run_apply_cache
