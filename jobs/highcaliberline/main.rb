require '../generic_import'
require './import'

import = HighCaliberLine.new("High Caliber Line", "www.highcaliberline.com")
import.set_standard_colors
import.run_parse_cache
import.run_transform 
import.run_apply_cache

#import = HighCaliberLine.new("AlCraft", "www.alcraft.com")
#import.run_parse_cache
#import.run_transform
#import.run_apply_cache
