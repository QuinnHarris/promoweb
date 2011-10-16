require '../generic_import'
require './import'
#require 'transform'

puts "Stating Fetch"

import = LeedsXLS.new
import.run_parse_cache
import.run_transform
import.run_apply_cache
