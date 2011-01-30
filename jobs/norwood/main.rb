require '../generic_import'

require 'import'
#require 'fetch'

#fetch

# NEW
# FUN, HOUSEWARES, MEETING, TECHNOLOGY, OUTDOOR, TRAVEL
# nor = Supplier.find_by_name("Norwood")
# %w(Fun Housewares Meeting Technology Outdoor Travel).each { |name| nor.children.create(:name => name) }

year = 2011

#list =
#[[%w(AUTO AWARD BAG DRINK GOLF HEALTH OFFICE WRITE), 'Hard Goods'],
# [%w(GV CALENDAR), 'Calendar']]

list = 
[['AUTO', 'Barlow'],
 ['AWARD', 'Jaffa'],
 ['BAG', 'AirTex'],
 ['CALENDAR', 'TRIUMPH'],
 ['DRINK', 'RCC'],
 ['GOLF', 'TeeOff'],
 ['GV', 'GOODVALU'],
 ['HEALTH', 'Pillow'],
 ['OFFICE', 'EOL'],
 ['WRITE', 'Souvenir'],
 ['FUN', 'Fun'],
 ['HOUSEWARES', 'Housewares'],
 ['MEETING', 'Meeting'],
 ['TECHNOLOGY', 'Technology'],
 ['OUTDOOR', 'Outdoor'],
 ['TRAVEL', 'Travel'],
]

list.each do |file, name|
  file_name = "#{year} #{file}"
  wf = WebFetch.new("http://norwood.com/files/productdata/#{year}/#{file_name}.zip")
  path = wf.get_path(Time.now - 30.days)
  dst_path = File.join(JOBS_DATA_ROOT,'norwood')
  dst_file = File.join(dst_path,"#{file_name}.xml")
  unless File.exists?(dst_file)
#    File.unlink(dst_file)
    system("unzip #{path} -d #{dst_path}")
  end
end

list.each do |file, name|
  import = NorwoodXML.new("norwood/#{year} #{file}.xml", name)
  import.run_parse_cache
  import.run_transform
  import.run_apply_cache
end
