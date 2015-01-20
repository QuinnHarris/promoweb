require '../generic_import'

# insert into decoration_techniques (name, unit_name, unit_default) VALUES ('Heat Transfer (area)', 'sq in', 3);

apply_decorations('Alphabroder') do |alpha|
  # Blank Bag Costs
  dec_grp = alpha.decoration_price_groups.create(
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
  dec_grp = alpha.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Screen Print") })
    dec_grp.entries.create({ :minimum => 1,
      :fixed_price_const => 0.0,
      :fixed_price_exp => 0.0,
      :fixed_price_marginal => Money.new(0),
      :fixed_price_fixed => Money.new(55.00),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(44.00),
        :marginal => Money.new(0),
        :minimum => 1 }]),

      :marginal_price_const => 16.6954093767187,
      :marginal_price_exp => -0.576560516885374,
      :marginal_price_marginal => Money.new(0.36),
      :marginal_price_fixed => Money.new(55.00),
      :marginal => PriceGroup.create_prices([
      { :fixed => Money.new(44.00),
        :marginal => Money.new(0.99*0.8),
        :minimum => 6 },
      { :fixed => Money.new(44.00),
        :marginal => Money.new(0.74*0.8),
        :minimum => 100 },
      { :fixed => Money.new(44.00),
        :marginal => Money.new(0.59*0.8),
        :minimum => 300 },
      { :fixed => Money.new(44.00),
        :marginal => Money.new(0.45*0.8),
        :minimum => 1000 }]) })

  # Heat Seal Transfer
  dec_grp = alpha.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Heat Transfer") })
    # <= 6
    dec_grp.entries.create({ :minimum => 1,
      :fixed_price_const => 10.0,
      :fixed_price_exp => -0.42254902000713,
      :fixed_price_marginal => Money.new(1.25),
      :fixed_price_fixed => Money.new(0),
      :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(20.0),
          :marginal => Money.new(9.00),
          :minimum => 1 },
        { :fixed => Money.new(20.0),
          :marginal => Money.new(4.50),
          :minimum => 6 },
        { :fixed => Money.new(20.0),
          :marginal => Money.new(2.30),
          :minimum => 12 },
        { :fixed => Money.new(0),
          :marginal => Money.new(2.30),
          :minimum => 24 },
        { :fixed => Money.new(0),
          :marginal => Money.new(1.50),
          :minimum => 300 },
        { :fixed => Money.new(0),
          :marginal => Money.new(1.25),
          :minimum => 1200 }]) })

    # > 6
  dec_grp.entries.create({ :minimum => 7,
     :fixed_price_const => 10.0,
     :fixed_price_exp => -0.42254902000713,
     :fixed_price_marginal => Money.new(1.25),
     :fixed_price_fixed => Money.new(0),
      :fixed => PriceGroup.create_prices([
         { :fixed => Money.new(20.0),
           :marginal => Money.new(9.00),
           :minimum => 1 },
         { :fixed => Money.new(20.0),
           :marginal => Money.new(4.50),
           :minimum => 6 },
         { :fixed => Money.new(20.0),
           :marginal => Money.new(2.30),
           :minimum => 12 },
         { :fixed => Money.new(0),
           :marginal => Money.new(2.30),
           :minimum => 24 },
         { :fixed => Money.new(0),
           :marginal => Money.new(1.50),
           :minimum => 300 },
         { :fixed => Money.new(0),
           :marginal => Money.new(1.25),
           :minimum => 1200 }]),
      :fixed_divisor => 1000,
      :fixed_offset => 9000,
      :marginal_divisor => 1000,
      :marginal_offset => 9000,

      :marginal_price_const => 0.0,
      :marginal_price_exp => 0.0,
      :marginal_price_marginal => Money.new(0.20),
      :marginal_price_fixed => Money.new(0),
      :marginal => PriceGroup.create_prices([
      { :fixed => Money.new(0),
        :marginal => Money.new(0.15),
        :minimum => 1 }]) })
         
    
  # Embroidery
  dec_grp = alpha.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Embroidery") })
    # <= 5000
    dec_grp.entries.create({ :minimum => 1,
      :fixed_price_const => 10.0,
      :fixed_price_exp => -0.42254902000713,
      :fixed_price_marginal => Money.new(1.25),
      :fixed_price_fixed => Money.new(50.00),
      :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(30.00),
          :marginal => Money.new(9.00),
          :minimum => 1 },
        { :fixed => Money.new(30.00),
          :marginal => Money.new(4.50),
          :minimum => 6 },
        { :fixed => Money.new(30.00),
          :marginal => Money.new(2.30),
          :minimum => 12 },
        { :fixed => Money.new(30.00),
          :marginal => Money.new(1.50),
          :minimum => 300 },
        { :fixed => Money.new(30.00),
          :marginal => Money.new(1.25),
          :minimum => 1200 }]) })
            
    # 10000 +
  dec_grp.entries.create({ :minimum => 10000,
     :fixed_price_const => 10.0,
     :fixed_price_exp => -0.42254902000713,
     :fixed_price_marginal => Money.new(1.25),
     :fixed_price_fixed => Money.new(50.00),
      :fixed => PriceGroup.create_prices([
         { :fixed => Money.new(30.00),
           :marginal => Money.new(9.00),
           :minimum => 1 },
         { :fixed => Money.new(30.00),
           :marginal => Money.new(4.50),
           :minimum => 6 },
         { :fixed => Money.new(30.00),
           :marginal => Money.new(2.30),
           :minimum => 12 },
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
      :marginal_price_marginal => Money.new(0.50),
      :marginal_price_fixed => Money.new(10.00),
      :marginal => PriceGroup.create_prices([
      { :fixed => Money.new(7.50),
        :marginal => Money.new(0.40),
        :minimum => 12 }]) })
end
