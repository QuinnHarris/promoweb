require '../generic_import'

# insert into decoration_techniques (name, unit_name, unit_default) VALUES ('Heat Transfer (area)', 'sq in', 3);

apply_decorations('Ash City') do |gemline|
  # Blank Bag Costs
  dec_grp = gemline.decoration_price_groups.create(
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

  # Heat Seal Transfer
  dec_grp = gemline.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Heat Transfer (area)") })
    # <= 6
   dec_grp.entries.create({ :minimum => 1,
      :fixed_price_const => 5.0,
      :fixed_price_exp => -0.38194934467248,
      :fixed_price_marginal => Money.new(1.25),
      :fixed_price_fixed => Money.new(50.00),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(15.00),
        :marginal => Money.new(6.00),
        :minimum => 1 },
      { :fixed => Money.new(15.00),
        :marginal => Money.new(1.75),
        :minimum => 6 },
      { :fixed => Money.new(0),
        :marginal => Money.new(1.75),
        :minimum => 24 },
      { :fixed => Money.new(0),
        :marginal => Money.new(1.50),
        :minimum => 300 },
      { :fixed => Money.new(0),
        :marginal => Money.new(1.25),
        :minimum => 1200 }]) })
            
            
    # > 6
  dec_grp.entries.create({ :minimum => 6,
      :fixed_price_const => 5.0,
      :fixed_price_exp => -0.38194934467248,
      :fixed_price_marginal => Money.new(1.25),
      :fixed_price_fixed => Money.new(50.00),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(15.00),
        :marginal => Money.new(6.00),
        :minimum => 1 },
      { :fixed => Money.new(15.00),
        :marginal => Money.new(1.75),
        :minimum => 6 },
      { :fixed => Money.new(0),
        :marginal => Money.new(1.75),
        :minimum => 24 },
      { :fixed => Money.new(0),
        :marginal => Money.new(1.50),
        :minimum => 300 },
      { :fixed => Money.new(0),
        :marginal => Money.new(1.25),
        :minimum => 1200 }]),
      :fixed_divisor => 1,
      :fixed_offset => 2,
      :marginal_divisor => 1,
      :marginal_offset => 2,
       
      :marginal_price_const => 0.0,
      :marginal_price_exp => 0.0,
      :marginal_price_marginal => Money.new(0.12),
      :marginal_price_fixed => Money.new(0),
      :marginal => PriceGroup.create_prices([
      { :fixed => Money.new(0),
        :marginal => Money.new(0.12),
        :minimum => 1 }]) })
         
    
  # Embroidery
  dec_grp = gemline.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Embroidery") })
    # <= 5000
    dec_grp.entries.create({ :minimum => 1,
      :fixed_price_const => 5.0,
      :fixed_price_exp => -0.38194934467248,
      :fixed_price_marginal => Money.new(1.25),
      :fixed_price_fixed => Money.new(50.00),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(30.00),
        :marginal => Money.new(6.00),
        :minimum => 1 },
      { :fixed => Money.new(30.00),
        :marginal => Money.new(1.75),
        :minimum => 6 },
      { :fixed => Money.new(30.00),
        :marginal => Money.new(1.50),
        :minimum => 300 },
      { :fixed => Money.new(30.00),
        :marginal => Money.new(1.25),
        :minimum => 1200 }]) })
            
    # 5001 - 7500
  dec_grp.entries.create({ :minimum => 10000,
      :fixed_price_const => 5.0,
      :fixed_price_exp => -0.38194934467248,
      :fixed_price_marginal => Money.new(1.25),
      :fixed_price_fixed => Money.new(50.00),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(30.00),
        :marginal => Money.new(6.00),
        :minimum => 1 },
      { :fixed => Money.new(30.00),
        :marginal => Money.new(1.75),
        :minimum => 6 },
      { :fixed => Money.new(30.00),
        :marginal => Money.new(1.50),
        :minimum => 300 },
      { :fixed => Money.new(30.00),
        :marginal => Money.new(1.25),
        :minimum => 1200 }]),
      :fixed_divisor => 1000,
      :fixed_offset => 9000,
      :marginal_divisor => 1000,
      :marginal_offset => 9000,
       
      :marginal_price_const => 0.0,
      :marginal_price_exp => 0.0,
      :marginal_price_marginal => Money.new(0.25),
      :marginal_price_fixed => Money.new(10.00),
      :marginal => PriceGroup.create_prices([
      { :fixed => Money.new(7.50),
        :marginal => Money.new(0.25),
        :minimum => 12 }]) })
end
