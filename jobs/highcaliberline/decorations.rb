require '../generic_import'

supplier = Supplier.find_by_name("High Caliber Line")

# Remove all old records
supplier.decoration_price_groups.each do |grp|
  grp.entries.each do |entry|
    fixed = entry.fixed
    marginal = entry.marginal
    
    entry.destroy
    
    fixed.destroy if fixed and fixed.decoration_price_entry_fixed.empty?
    marginal.destroy if marginal and marginal.decoration_price_entry_marginal.empty?
  end
  grp.destroy
end

dec_grp = supplier.decoration_price_groups.create(
  { :technique => DecorationTechnique.find_by_name("None") })
dec_grp.entries.create({ :minimum => 0,
                         :fixed_price_const => 0.0,
                         :fixed_price_exp => 0.0,
                         :fixed_price_marginal => Money.new(0),
                         :fixed_price_fixed => Money.new(0),   
                         :fixed => PriceGroup.create_prices([
                                                             { :fixed => Money.new(0),
                                                               :marginal => Money.new(0),
                                                               :minimum => 0 }]) })
    
# Screen Print (level 2)
['Screen Print', 'Laser Engrave'].each do |name|
dec_grp = supplier.decoration_price_groups.create(
            { :technique => DecorationTechnique.find_by_name(name) })  
dec_grp.entries.create({ :minimum => 1,
                         :fixed_price_const => 0.0,
                         :fixed_price_exp => 0.0,
                         :fixed_price_marginal => Money.new(0),
                         :fixed_price_fixed => Money.new(50.0),
                         :fixed => PriceGroup.create_prices([
                                                             { :fixed => Money.new(40.0),
                                                               :marginal => Money.new(0),
                                                               :minimum => 1 }]),
                         
                         :marginal_price_const => 0,
                         :marginal_price_exp => 0,
                         :marginal_price_marginal => Money.new(0.3),
                         :marginal_price_fixed => Money.new(50.0),
                         :marginal => PriceGroup.create_prices(
                                                               { 1 => 0.30 }.collect do |min, price|
                                                                 { :fixed => Money.new(40.0),
                                                                   :marginal => Money.new(price*0.8),
                                                                   :minimum => min }
                                                               end + [{ :minimum => 5000 }]) })

end
