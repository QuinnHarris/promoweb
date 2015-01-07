require File.dirname(__FILE__) + '/../config/environment'

Product.where(deleted: false).find_each do |product|
  puts product.id
  pc = PriceCollectionCompetition.new(product)
  begin
    pc.calculate_price
  rescue
    puts "FAIL"
  end
end
