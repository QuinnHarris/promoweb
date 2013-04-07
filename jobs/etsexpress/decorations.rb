require '../generic_import'

apply_decorations('ETS Express Inc') do |ets|
  dec_grp = ets.decoration_price_groups.create(
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

  dec_grp = ets.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Screen Print") })  
    dec_grp.entries.create({ :minimum => 1,
      :fixed_price_const => 0.0,
      :fixed_price_exp => 0.0,
      :fixed_price_marginal => Money.new(0),
      :fixed_price_fixed => Money.new(50.00),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(40.00),
        :marginal => Money.new(0),
        :minimum => 1 }]),
        
      :marginal_price_const => 0.0,
      :marginal_price_exp => 0.0,
      :marginal_price_marginal => Money.new(0.75),
      :marginal_price_fixed => Money.new(50.00),
      :marginal => PriceGroup.create_prices([
      { :fixed => Money.new(40.00),
        :marginal => Money.new(0.6),
        :minimum => 1 }]) })

  dec_grp = ets.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name('4 Color Photographic Paper Insert') })  
    dec_grp.entries.create({ :minimum => 1,
      :fixed_price_const => 0.0,
      :fixed_price_exp => 0.0,
      :fixed_price_marginal => Money.new(0),
      :fixed_price_fixed => Money.new(80.00),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(64.00),
        :marginal => Money.new(0),
        :minimum => 1 }]) })
end
