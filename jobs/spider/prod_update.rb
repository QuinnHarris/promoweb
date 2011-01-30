require File.dirname(__FILE__) + '/../../config/environment'

Product.find(:all, :order => 'id', :conditions => 'id not in (2445)').each do |product|
  puts "Product: #{product.id}"
  pc = PriceCollectionCompetition.new(product)
  pc.calculate_price
end
