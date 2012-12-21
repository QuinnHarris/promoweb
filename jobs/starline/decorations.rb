require '../generic_import'

apply_decorations('Starline') do |starline|
  # Blank Bag Costs
  dec_grp = starline.decoration_price_groups.create(
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
  dec_grp = starline.decoration_price_groups.create(
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
      :marginal_price_marginal => Money.new(0.50),
      :marginal_price_fixed => Money.new(50.00),
      :marginal => PriceGroup.create_prices([
      { :fixed => Money.new(40.00),
        :marginal => Money.new(0.4),
        :minimum => 1 }]) })


  # Laser Engrave Costs
  dec_grp = starline.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Laser Engrave") })  
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
      :marginal_price_marginal => Money.new(1.2),
      :marginal_price_fixed => Money.new(50.00),
      :marginal => PriceGroup.create_prices([
      { :fixed => Money.new(40.00),
        :marginal => Money.new(1.2*0.8),
        :minimum => 1 }]) })


  # Deboss Costs
  dec_grp = starline.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Deboss") })  
    dec_grp.entries.create({ :minimum => 1,
      :fixed_price_const => 0.0,
      :fixed_price_exp => 0.0,
      :fixed_price_marginal => Money.new(0),
      :fixed_price_fixed => Money.new(70.00),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(70.00*0.8),
        :marginal => Money.new(0),
        :minimum => 1 }]) })


  # Embroidery
  dec_grp = starline.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Embroidery") })
    # <= 8000
    dec_grp.entries.create({ :minimum => 1,
      :fixed_price_const => 3.39784575085945,
      :fixed_price_exp => -0.31531808602758,
      :fixed_price_marginal => Money.new(1.6),
      :fixed_price_fixed => Money.new(50.00),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(40.00),
        :marginal => Money.new(4.69*0.8),
        :minimum => 6 },
      { :fixed => Money.new(40.00),
        :marginal => Money.new(2.75*0.8),
        :minimum => 24 },
      { :fixed => Money.new(40.00),
        :marginal => Money.new(2.50*0.8),
        :minimum => 100 },
      { :fixed => Money.new(40.00),
        :marginal => Money.new(2.25*0.8),
        :minimum => 300 },
      { :fixed => Money.new(40.00),
        :marginal => Money.new(2.00*0.8),
        :minimum => 2000 }]) })
            
    # Above 8000
    dec_grp.entries.create({ :minimum => 8001,
      :fixed_price_const => 3.39784575085945,
      :fixed_price_exp => -0.31531808602758,
      :fixed_price_marginal => Money.new(1.6),
      :fixed_price_fixed => Money.new(50.00),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(40.00),
        :marginal => Money.new(4.69*0.8),
        :minimum => 6 },
      { :fixed => Money.new(40.00),
        :marginal => Money.new(2.75*0.8),
        :minimum => 24 },
      { :fixed => Money.new(40.00),
        :marginal => Money.new(2.50*0.8),
        :minimum => 100 },
      { :fixed => Money.new(40.00),
        :marginal => Money.new(2.25*0.8),
        :minimum => 300 },
      { :fixed => Money.new(40.00),
        :marginal => Money.new(2.00*0.8),
        :minimum => 2000 }]),
      :fixed_divisor => 1000,
      :fixed_offset => 0,
      :marginal_divisor => 1000,
      :marginal_offset => 7000,
       
      :marginal_price_const => 2.5961085961212,
      :marginal_price_exp => -0.22570809716171,
      :marginal_price_marginal => Money.new(0.344),
      :marginal_price_fixed => Money.new(25.00),
      :marginal => PriceGroup.create_prices([
      { :fixed => Money.new(40.00),
        :marginal => Money.new(0.94*0.8),
        :minimum => 6 },
      { :fixed => Money.new(40.00),
        :marginal => Money.new(0.74*0.8),
        :minimum => 24 },
      { :fixed => Money.new(40.00),
        :marginal => Money.new(0.62*0.8),
        :minimum => 100 },
      { :fixed => Money.new(40.00),
        :marginal => Money.new(0.50*0.8),
        :minimum => 300 },
      { :fixed => Money.new(40.00),
        :marginal => Money.new(0.43*0.8),
        :minimum => 2000 }]) })
end
