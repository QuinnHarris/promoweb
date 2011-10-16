require '../generic_import'

require './import'
require './fetch'

fetch

import = GemlineXML.new
import.run_parse_cache
import.run_transform
import.run_apply_cache

