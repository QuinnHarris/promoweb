require './generic_import'

{ 'ashcity' => 'AshCityXML',
  'bulletline' => 'BulletLine',
#  'digispec' => 'DigispecWeb',
  'gemline' => 'GemlineXML',
  'highcaliberline' => 'HighCaliberLine',
  'lanco' => 'LancoSOAP',
  'leeds' => 'LeedsXLS',
  'logoincluded' => 'LogoIncludedXML',
  'norwood' => 'NorwoodAll',
  'primeline' => 'PrimeLineWeb',
}.each do |dir, klass|
  puts "Applying #{dir} #{klass}"

  require "./#{dir}/import"
  import = Kernel.const_get(klass).new
  import.run_parse_cache
  import.run_transform
  import.run_apply_cache
end
