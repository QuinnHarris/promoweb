require '../generic_import'
require './import'

import = HighCaliberLine.new("21-02-2012")
import.set_standard_colors
import.run_parse_cache
import.run_transform 
import.run_apply_cache

#import = HighCaliberLine.new("AlCraft", "www.alcraft.com")
#import.run_parse_cache
#import.run_transform
#import.run_apply_cache
