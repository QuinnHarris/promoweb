require 'import'

lanco = LancoSOAP.new
lanco.run_parse_cache
lanco.run_transform
lanco.run_apply_cache
