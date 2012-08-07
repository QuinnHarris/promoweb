require '../generic_import'

apply_decorations('Sweda') do |supplier|
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
  
  # Screen Print
  setup_price = Money.new(50.0)
  dec_grp = supplier.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Screen Print") })  
    dec_grp.entries.create({ :minimum => 1,
      :fixed_price_const => 0.0,
      :fixed_price_exp => 0.0,
      :fixed_price_marginal => Money.new(0),
      :fixed_price_fixed => setup_price,
      :fixed => PriceGroup.create_prices([
      { :fixed => setup_price*0.8,
        :marginal => Money.new(0),
        :minimum => 1 }]),
       :marginal_price_const => 121.840483627152,
      :marginal_price_exp => -0.89595053517495,
      :marginal_price_marginal => Money.new(0.32),
      :marginal_price_fixed => setup_price,
      :marginal => PriceGroup.create_prices(
        {     1 => 2.50,
             50 => 1.25,
            100 => 0.75,
            250 => 0.50,
           1000 => 0.40 }.collect do |min, price|
            { :fixed => setup_price * 0.8,
              :marginal => Money.new(price*0.8),
              :minimum => min }
        end + [{ :minimum => 2000 }]) })

end
