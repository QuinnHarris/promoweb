require '../generic_import'
require 'import'

import = LogoIncludedXML.new("LogoIncluded.xml")
import.fetch
import.run_parse_cache
import.run_transform
import.run_apply_cache
