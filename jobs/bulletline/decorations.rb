require '../generic_import'

supplier = Supplier.find_by_name("Bullet Line")

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
dec_grp = supplier.decoration_price_groups.create(
            { :technique => DecorationTechnique.find_by_name("Screen Print") })  
dec_grp.entries.create({ :minimum => 1,
                         :fixed_price_const => 0.0,
                         :fixed_price_exp => 0.0,
                         :fixed_price_marginal => Money.new(0),
                         :fixed_price_fixed => Money.new(45.0),
                         :fixed => PriceGroup.create_prices([
                                                             { :fixed => Money.new(36.0),
                                                               :marginal => Money.new(0),
                                                               :minimum => 1 }]),
                         
                         :marginal_price_const => 399.843496461967,
                         :marginal_price_exp => -0.04225117615537,
                         :marginal_price_marginal => Money.new(1),
                         :marginal_price_fixed => Money.new(45.0),
                         :marginal => PriceGroup.create_prices(
                                                               {     1 => 0.35,
                                                                  5000 => 0.30,
                                                                 10000 => 0.25,
                                                                 20000 => 0.20 }.collect do |min, price|
                                                                 { :fixed => Money.new(36.0),
                                                                   :marginal => Money.new(price*0.8),
                                                                   :minimum => min }
                                                               end + [{ :minimum => 50000 }]) })

# Laser Engrave (level 2)
dec_grp = supplier.decoration_price_groups.create(
            { :technique => DecorationTechnique.find_by_name("Laser Engrave") })
dec_grp.entries.create({ :minimum => 1,
                         :fixed_price_const => 0.0,
                         :fixed_price_exp => 0.0,
                         :fixed_price_marginal => Money.new(0),
                         :fixed_price_fixed => Money.new(45.0),
                         :fixed => PriceGroup.create_prices([
                                                             { :fixed => Money.new(36.0),
                                                               :marginal => Money.new(0),
                                                               :minimum => 1 }]),
                         
                         :marginal_price_const => 399.843496461967,
                         :marginal_price_exp => -0.04225117615537,
                         :marginal_price_marginal => Money.new(1),
                         :marginal_price_fixed => Money.new(45.0),
                         :marginal => PriceGroup.create_prices(
                                                               {     1 => 0.35,
                                                                  5000 => 0.30,
                                                                 10000 => 0.25,
                                                                 20000 => 0.20 }.collect do |min, price|
                                                                 { :fixed => Money.new(36.0),
                                                                   :marginal => Money.new(price*0.8),
                                                                   :minimum => min }
                                                               end + [{ :minimum => 50000 }]) })


# Deboss (level 3)
dec_grp = supplier.decoration_price_groups.create(
            { :technique => DecorationTechnique.find_by_name("Deboss") })
dec_grp.entries.create({ :minimum => 1,
                         :fixed_price_const => 0.0,
                         :fixed_price_exp => 0.0,
                         :fixed_price_marginal => Money.new(0),
                         :fixed_price_fixed => Money.new(45.0),
                         :fixed => PriceGroup.create_prices([
                                                             { :fixed => Money.new(36.0),
                                                               :marginal => Money.new(0),
                                                               :minimum => 1 }]),
                         
                         :marginal_price_const => -0.50162231757628,
                         :marginal_price_exp => 0.02860340135229,
                         :marginal_price_marginal => Money.new(1.0),
                         :marginal_price_fixed => Money.new(45.0),
                         :marginal => PriceGroup.create_prices(
                                                               {     1 => 0.45,
                                                                  5000 => 0.40,
                                                                 10000 => 0.35,
                                                                 20000 => 0.30,
                                                                 50000 => 0.25 }.collect do |min, price|
                                                                 { :fixed => Money.new(36.0),
                                                                   :marginal => Money.new(price*0.8),
                                                                   :minimum => min }
                                                               end + [{ :minimum => 100000 }]) })


# Photo Transfer (level 3)
dec_grp = supplier.decoration_price_groups.create(
            { :technique => DecorationTechnique.find_by_name("Photo Transfer") })
dec_grp.entries.create({ :minimum => 1,
                         :fixed_price_const => 0.0,
                         :fixed_price_exp => 0.0,
                         :fixed_price_marginal => Money.new(0),
                         :fixed_price_fixed => Money.new(45.0),
                         :fixed => PriceGroup.create_prices([
                                                             { :fixed => Money.new(36.0),
                                                               :marginal => Money.new(0),
                                                               :minimum => 1 }]),
                         
                         :marginal_price_const => -0.50162231757628,
                         :marginal_price_exp => 0.02860340135229,
                         :marginal_price_marginal => Money.new(1.0),
                         :marginal_price_fixed => Money.new(45.0),
                         :marginal => PriceGroup.create_prices(
                                                               {     1 => 0.45,
                                                                  5000 => 0.40,
                                                                 10000 => 0.35,
                                                                 20000 => 0.30,
                                                                 50000 => 0.25 }.collect do |min, price|
                                                                 { :fixed => Money.new(36.0),
                                                                   :marginal => Money.new(price*0.8),
                                                                   :minimum => min }
                                                               end + [{ :minimum => 100000 }]) })
