require '../generic_import'

DecorationTechnique.create(:name => 'Dye Sublimation')
DecorationTechnique.create(:name => 'Offset Lithography')

apply_decorations('DigiSpec') do |digispec|
  # Dye Sublimation
  dec_grp = digispec.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Dye Sublimation") })
    dec_grp.entries.create({ :minimum => 0,
      :fixed_price_const => 0.0,
      :fixed_price_exp => 0.0,
      :fixed_price_marginal => Money.new(0),
      :fixed_price_fixed => Money.new(50.00),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(40.00),
        :marginal => Money.new(0),
        :minimum => 0 }]) })


  # Offset Lithography
  dec_grp = digispec.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Offset Lithography") })
    dec_grp.entries.create({ :minimum => 0,
      :fixed_price_const => 0.0,
      :fixed_price_exp => 0.0,
      :fixed_price_marginal => Money.new(0),
      :fixed_price_fixed => Money.new(50.00),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(40.00),
        :marginal => Money.new(0),
        :minimum => 0 }]) })
end
