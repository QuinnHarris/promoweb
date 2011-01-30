require 'sites'
require 'hpricot'

def get_doc(url)
  fc = FileCache.new("spider")
  res = fc.get(URI.parse(url))
  Hpricot(res.body)
end
