require '../generic_import'

apply_decorations('Gemline') do |gemline|
  # Blank Bag Costs
  dec_grp = gemline.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("None") })
    dec_grp.entries.create({ :minimum => 0,
      :fixed_price_const => 0.0,
      :fixed_price_exp => 0.0,
      :fixed_price_marginal => Money.new(-0.31),
      :fixed_price_fixed => Money.new(0),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(0),
        :marginal => Money.new(-0.31),
        :minimum => 0 }]) })
  
  
  # Screen Print Costs
  dec_grp = gemline.decoration_price_groups.create(
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
        
    
  # Embroidery
  dec_grp = gemline.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Embroidery") })
    # <= 5000
    dec_grp.entries.create({ :minimum => 1,
      :fixed_price_const => 0.941286178930541,
      :fixed_price_exp => -0.200474815775463,
      :fixed_price_marginal => Money.new(1.59),
      :fixed_price_fixed => Money.new(100.00),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(80.00),
        :marginal => Money.new(2.80*0.8),
        :minimum => 6 },
      { :fixed => Money.new(80.00),
        :marginal => Money.new(2.55*0.8),
        :minimum => 100 },
      { :fixed => Money.new(80.00),
        :marginal => Money.new(2.29*0.8),
        :minimum => 300 }]) })
            
    # 5001 - 7500
    dec_grp.entries.create({ :minimum => 5001,
      :fixed_price_const => 0.760356986083937,
      :fixed_price_exp => -0.163050672252103,
      :fixed_price_marginal => Money.new(1.98),
      :fixed_price_fixed => Money.new(100.00),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(80.00),
        :marginal => Money.new(3.30*0.8),
        :minimum => 6 },
      { :fixed => Money.new(80.00),
        :marginal => Money.new(3.05*0.8),
        :minimum => 100 },
      { :fixed => Money.new(80.00),
        :marginal => Money.new(2.79*0.8),
        :minimum => 300 }]),
      :fixed_divisor => 1000,
      :fixed_offset => 0,
      :marginal_divisor => 1000,
      :marginal_offset => 2500,
       
      :marginal_price_const => 0.0,
      :marginal_price_exp => 0.0,
      :marginal_price_marginal => Money.new(0.27),
      :marginal_price_fixed => Money.new(25.00),
      :marginal => PriceGroup.create_prices([
      { :fixed => Money.new(20.00),
        :marginal => Money.new(0.24),
        :minimum => 6 }]) })

        
  # Deboss
  dec_grp = gemline.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Deboss") })  
    dec_grp.entries.create({ :minimum => 1,
      :fixed_price_const => 0.0,
      :fixed_price_exp => 0.0,
      :fixed_price_marginal => Money.new(0),
      :fixed_price_fixed => Money.new(70.00),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(57.00),
        :marginal => Money.new(0),
        :minimum => 1 }]),
        
      :marginal_price_const => 16.6954093767187,
      :marginal_price_exp => -0.576560516885374,
      :marginal_price_marginal => Money.new(0.36),
      :marginal_price_fixed => Money.new(70.00),
      :marginal => PriceGroup.create_prices([
      { :fixed => Money.new(56.00),
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
        
        
  # Personalization
  dec_grp = gemline.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Personalization") })
    dec_grp.entries.create({ :minimum => 1,
      :fixed_price_const => 0.0,
      :fixed_price_exp => 0.0,
      :fixed_price_marginal => Money.new(0),
      :fixed_price_fixed => Money.new(0),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(0),
        :marginal => Money.new(0),
        :minimum => 1 }]),
          
      :marginal_divisor => 25,
      :marginal_price_const => 0.0,
      :marginal_price_exp => 0.0,
      :marginal_price_marginal => Money.new(0),
      :marginal_price_fixed => Money.new(30.00),
      :marginal => PriceGroup.create_prices([
      { :fixed => Money.new(24.00),
        :marginal => Money.new(0),
        :minimum => 1 }])   
      })


  # Photo
  dec_grp = gemline.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Photo Transfer") })  
    dec_grp.entries.create({ :minimum => 1,
      :fixed_price_const => 3.53025664134072,
      :fixed_price_exp => -0.43371131512659,
      :fixed_price_marginal => Money.new(1.70),
      :fixed_price_fixed => Money.new(0),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(0),
        :marginal => Money.new(2.80*0.8),
        :minimum => 6 },
      { :fixed => Money.new(0),
        :marginal => Money.new(2.55*0.8),
        :minimum => 100 },
      { :fixed => Money.new(0),
        :marginal => Money.new(2.20*0.8),
        :minimum => 300 },
      { :fixed => Money.new(0),
        :marginal => Money.new(2.05*0.8),
        :minimum => 1000 }]),
        
      :marginal_price_const => 3.53025664134072,
      :marginal_price_exp => -0.43371131512659,
      :marginal_price_marginal => Money.new(1.70),
      :marginal_price_fixed => Money.new(0),
      :marginal => PriceGroup.create_prices([
      { :fixed => Money.new(0),
        :marginal => Money.new(2.80*0.8),
        :minimum => 6 },
      { :fixed => Money.new(0),
        :marginal => Money.new(2.55*0.8),
        :minimum => 100 },
      { :fixed => Money.new(0),
        :marginal => Money.new(2.20*0.8),
        :minimum => 300 },
      { :fixed => Money.new(0),
        :marginal => Money.new(2.05*0.8),
        :minimum => 1000 }]) })  
    
    
  # Patch
  dec_grp = gemline.decoration_price_groups.create(
   { :technique => DecorationTechnique.find_by_name("Patch") })
     dec_grp.entries.create({ :minimum => 1,
      :fixed_price_const => 0.0,
      :fixed_price_exp => 0.0,
      :fixed_price_marginal => Money.new(0.40),
      :fixed_price_fixed => Money.new(270.00),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(240.00),
        :marginal => Money.new(0.35),
        :minimum => 1 }]),
      })
        
        
  # LogoMagic
  dec_grp = gemline.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("LogoMagic") })
    dec_grp.entries.create({ :minimum => 1,
      :fixed_price_const => 0.0,
      :fixed_price_exp => 0.0,
      :fixed_price_marginal => Money.new(0),
      :fixed_price_fixed => Money.new(55.00),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(44.00),
        :marginal => Money.new(0),
        :minimum => 1 }]),
      })


  # Laser Engrave
  dec_grp = gemline.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Laser Engrave") })
    dec_grp.entries.create({ :minimum => 1,
      :fixed_price_const => 0.0,
      :fixed_price_exp => 0.0,
      :fixed_price_marginal => Money.new(0),
      :fixed_price_fixed => Money.new(0),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(0),
        :marginal => Money.new(0),
        :minimum => 1 }]),
      }) 
end
