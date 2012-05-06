require '../generic_import'
require './import'

lanco = LancoXLS.new
lanco.set_standard_colors
lanco.run_parse_cache
lanco.run_transform
lanco.run_apply_cache
