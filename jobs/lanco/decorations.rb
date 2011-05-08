require '../generic_import'

apply_decorations('Lanco') do |supplier|
  # Blank Bag Costs
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
  
  
  # Screen Print Costs
  dec_grp = supplier.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Screen Print") })  
    dec_grp.entries.create({ :minimum => 1,
      :fixed_price_const => 0.0,
      :fixed_price_exp => 0.0,
      :fixed_price_marginal => Money.new(0),
      :fixed_price_fixed => Money.new(45.00),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(36.00),
        :marginal => Money.new(0),
        :minimum => 1 }]),
        
      :marginal_price_const => 1,
      :marginal_price_exp => 0,
      :marginal_price_marginal => Money.new(0.20),
      :marginal_price_fixed => Money.new(45.00),
      :marginal => PriceGroup.create_prices([
      { :fixed => Money.new(36.00),
        :marginal => Money.new(0.2*0.8),
        :minimum => 1 }]) })  
        

end
