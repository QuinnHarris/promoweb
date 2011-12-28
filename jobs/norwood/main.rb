require '../generic_import'
require './import'
#require 'fetch'

norwood = NorwoodAll.new
norwood.fetch
norwood.apply_all
