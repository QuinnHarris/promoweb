require '../generic_import'

apply_decorations('The Magnet Group') do |leeds|

#None
  dec_grp = leeds.decoration_price_groups.create(
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

# 4 Color Photographic
  dec_grp = leeds.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("4 Color Photographic") })
    dec_grp.entries.create({ :minimum => 0,
      :fixed_price_const => 0.0,
      :fixed_price_exp => 0.0,
      :fixed_price_marginal => Money.new(0),
      :fixed_price_fixed => Money.new(0),   
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(0),
        :marginal => Money.new(0),
        :minimum => 0 }]) })
end
