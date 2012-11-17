require File.dirname(__FILE__) + '/../config/environment'

#product = Product.find(11398)
#product.destroy

products = Product.find(:all, :conditions =>
  "supplier_num in (SELECT supplier_num FROM products WHERE supplier_id in (SELECT id from suppliers WHERE parent_id = 64) GROUP BY supplier_num HAVING count(*) > 1) AND supplier_id in (SELECT id from suppliers WHERE parent_id = 64)", :order => 'id')

ids = []
products.group_by { |p| p.supplier_num }.each do |num, list|
  raise "not two: #{num} #{list.collect { |i| i.id }.join(',')}" unless list.length == 2
  old, new = list
  puts new.id
  ids << new.id
  Product.transaction do
    old.supplier_id = new.supplier_id
    new.destroy
    old.save!
  end
end

puts ids.join(' ')
