require '../generic_import'
require 'import'

import = PrimeLineWeb.new
import.parse_web
import.run_parse_cache
import.run_transform
import.run_apply_cache
