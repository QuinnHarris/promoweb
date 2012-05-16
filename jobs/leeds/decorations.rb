require '../generic_import'

apply_decorations('Leeds') do |leeds|
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
    
    
    # Screen Print
    dec_grp = leeds.decoration_price_groups.create(
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

        :marginal_price_const => 29.372958454211,
        :marginal_price_exp => -0.785213457768842,
        :marginal_price_marginal => Money.new(0.36),
        :marginal_price_fixed => Money.new(55.00),
        :marginal => PriceGroup.create_prices(
          {     1 => 0.85,
              100 => 0.60,
              300 => 0.45,
             2500 => 0.40,
            10000 => 0.35 }.collect do |min, price|
              { :fixed => Money.new(44.00),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]) })


    # Photo Real
    dec_grp = leeds.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Photo Transfer") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 4.42804779005673,
        :fixed_price_exp => -0.3362955759314,
        :fixed_price_marginal => Money.new(1.36),
        :fixed_price_fixed => Money.new(180.00),
        :fixed => PriceGroup.create_prices(
          {     1 => 3.40,
              100 => 2.40,
             1200 => 1.95,
             2500 => 1.70,
            10000 => 1.50 }.collect do |min, price|
              { :fixed => Money.new(180.00*0.8),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]),

        :marginal_price_const => 4.39913959003335,
        :marginal_price_exp => -0.33558443680551,
        :marginal_price_marginal => Money.new(1.568),
        :marginal_price_fixed => Money.new(180.00),
        :marginal => PriceGroup.create_prices(
          {     1 => 3.91,
              100 => 2.76,
             1200 => 2.24,
             2500 => 1.96,
            10000 => 1.73 }.collect do |min, price|
              { :fixed => Money.new(180.00*0.8),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]) })
        


    # Embroidery
    dec_grp = leeds.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Embroidery") })
      # <= 7500
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 1.00534759358289,
        :fixed_price_exp => -0.17056319392749,
        :fixed_price_marginal => Money.new(1.50),
        :fixed_price_fixed => Money.new(20.00),
        :fixed => emb_fixed_grp = PriceGroup.create_prices(
          {     1 => 2.55,
              300 => 2.10,
             1200 => 2.00,
             2500 => 1.90,
             5000 => 1.85,
            10000 => 1.80 }.collect do |min, price|
              { :fixed => Money.new(16.00),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]),

        :fixed_divisor => 1000,
        :fixed_offset => 0,
        :marginal_divisor => 1000,
        :marginal_offset => 0,

        :marginal => PriceGroup.create_prices([
          { :fixed => Money.new(16.00),
            :marginal => Money.new(0),
            :minimum => 1},
          { :minimum => 15000 }]) })

      # > 7500
      dec_grp.entries.create({ :minimum => 7500,
       :fixed_price_const => 1.00534759358289,
        :fixed_price_exp => -0.17056319392749,
        :fixed_price_marginal => Money.new(1.50),
        :fixed_price_fixed => Money.new(20.00),
        :fixed => emb_fixed_grp,

        :fixed_divisor => 1000,
        :fixed_offset => 0,
        :marginal_divisor => 1000,
        :marginal_offset => 6500,

        :marginal_price_const => 0,
        :marginal_price_exp => 0,
        :marginal_price_marginal => Money.new(0.34),
        :marginal_price_fixed => Money.new(20.00),

        :marginal => PriceGroup.create_prices([
          { :fixed => Money.new(16.00),
            :marginal => Money.new(0.38*0.8),
            :minimum => 1},
          { :minimum => 15000 }]) })           


        
    # Deboss
    dec_grp = leeds.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Deboss") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => Money.new(0),
        :fixed_price_fixed => Money.new(75.00),
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(75.00*0.8),
          :marginal => Money.new(0),
          :minimum => 1 }]),

        :marginal_price_const => 1.62665947436704,
        :marginal_price_exp => -0.385320956616481,
        :marginal_price_marginal => Money.new(0.85),
        :marginal_price_fixed => Money.new(75.00),
        :marginal => PriceGroup.create_prices(
          {     1 => 1.25,
              100 => 1.15,
              300 => 1.00,
             1200 => 0.95,
             2500 => 0.85,
             5000 => 0.78,
            10000 => 0.68 }.collect do |min, price|
              { :fixed => Money.new(60.00*0.8),
                :marginal => Money.new(price*0.8),
                :minimum => min }
           end + [{ :minimum => 15000 }]) })


    # Stamp, duplicate of Deboss
    dec_grp = leeds.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Stamp") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => Money.new(0),
        :fixed_price_fixed => Money.new(75.00),
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(75.00*0.8),
          :marginal => Money.new(0),
          :minimum => 1 }]),

        :marginal_price_const => 1.62665947436704,
        :marginal_price_exp => -0.385320956616481,
        :marginal_price_marginal => Money.new(0.85),
        :marginal_price_fixed => Money.new(75.00),
        :marginal => PriceGroup.create_prices(
          {     1 => 1.25,
              100 => 1.15,
              300 => 1.00,
             1200 => 0.95,
             2500 => 0.85,
             5000 => 0.78,
            10000 => 0.68 }.collect do |min, price|
              { :fixed => Money.new(60.00*0.8),
                :marginal => Money.new(price*0.8),
                :minimum => min }
           end + [{ :minimum => 15000 }]) })


   # Laser Engrave
    dec_grp = leeds.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Laser Engrave") })  
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => Money.new(0),
        :fixed_price_fixed => Money.new(40.00),
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(40.00*0.8),
          :marginal => Money.new(0),
          :minimum => 1 }]),

        :marginal_price_const => 11.9264151450896,
        :marginal_price_exp => -0.53517598338089,
        :marginal_price_marginal => Money.new(0.32),
        :marginal_price_fixed => Money.new(30.00),
        :marginal => PriceGroup.create_prices(
          {     1 => 0.85,
              100 => 0.60,
              300 => 0.45,
             2500 => 0.40,
            10000 => 0.35 }.collect do |min, price|
              { :fixed => Money.new(30.00*0.8),
                :marginal => Money.new((price*100.0*0.8).to_i),
                :minimum => min }
          end + [{ :minimum => 15000 }]) })



  # Dome
    dec_grp = leeds.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Dome") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 3.17636460716223,
        :fixed_price_exp => -0.2770525557931,
        :fixed_price_marginal => Money.new(0.60),
        :fixed_price_fixed => Money.new(0),
        :fixed => PriceGroup.create_prices(
          {     1 => 1.25,
              100 => 1.15,
              300 => 1.00,
             1200 => 0.95,
             2500 => 0.85,
             5000 => 0.78,
            10000 => 0.69 }.collect do |min, price|
              { :fixed => Money.new(0),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]),

        :marginal_price_const => 2.21603786206194,
        :marginal_price_exp => -0.23478317491358,
        :marginal_price_marginal => Money.new(0.75),
        :marginal_price_fixed => Money.new(0),
        :marginal => PriceGroup.create_prices(
          {     1 => 1.56,
              100 => 1.44,
              300 => 1.25,
             1200 => 1.19,
             2500 => 1.06,
             5000 => 0.97,
            10000 => 0.86 }.collect do |min, price|
              { :fixed => Money.new(0),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]) })
end
