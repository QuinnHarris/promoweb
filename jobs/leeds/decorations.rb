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
      { :technique => DecorationTechnique.find_by_name('Screen Print') })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => Money.new(0),
        :fixed_price_fixed => Money.new(55.0),
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(55.0*0.8),
          :marginal => Money.new(0),
          :minimum => 1 }]),

        :marginal_price_const => 4.22288303630103, 
        :marginal_price_exp => -0.37598607447048,
        :marginal_price_marginal => Money.new(0.392),
        :marginal_price_fixed => Money.new(40.00),
        :marginal => PriceGroup.create_prices(
          {     1 => 0.99,
               50 => 0.79,
              150 => 0.69,
              500 => 0.49 }.collect do |min, price|
              { :fixed => Money.new(32.00),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]) })

   # Screen Print
  [['Laser Engrave - Level 1', 55.0], ['PhotoGrafixx - Level 1', 95.0], ['Deboss', 75.0]].each do |dec_name, dec_setup|
    dec_grp = leeds.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name(dec_name) })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => Money.new(0),
        :fixed_price_fixed => Money.new(dec_setup),
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(dec_setup*0.8),
          :marginal => Money.new(0),
          :minimum => 1 }]),

        :marginal_price_const => 4.22288303630103, 
        :marginal_price_exp => -0.37598607447048,
        :marginal_price_marginal => Money.new(0.392),
        :marginal_price_fixed => Money.new(dec_setup),
        :marginal => PriceGroup.create_prices(
          {     1 => 0.99,
               50 => 0.79,
              150 => 0.69,
              500 => 0.49 }.collect do |min, price|
              { :fixed => Money.new(dec_setup*0.8),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]) })
  end

    # Laser - 2
    dec_grp = leeds.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Laser Engrave - Level 2") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 1.83505451488476,
        :fixed_price_exp => -0.36626152372604,
        :fixed_price_marginal => Money.new(1.272),
        :fixed_price_fixed => Money.new(55.0),
        :fixed => PriceGroup.create_prices(
          {     1 => 1.99,
               50 => 1.79,
              150 => 1.69,
              500 => 1.59 }.collect do |min, price|
              { :fixed => Money.new(55.00*0.8),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]),

        :marginal_price_const => 1.83505451488476,
        :marginal_price_exp => -0.36626152372604,
        :marginal_price_marginal => Money.new(1.272),
        :marginal_price_fixed => Money.new(55.00),
        :marginal => PriceGroup.create_prices(
          {     1 => 1.99,
               50 => 1.79,
              150 => 1.69,
              500 => 1.59 }.collect do |min, price|
              { :fixed => Money.new(55.00*0.8),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]) })


    # Photo Real
    dec_grp = leeds.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("PhotoGrafixx - Level 2,3") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 27.9798139127662,
        :fixed_price_exp => -0.83602431030508,
        :fixed_price_marginal => Money.new(0.792),
        :fixed_price_fixed => Money.new(95.0),
        :fixed => PriceGroup.create_prices(
          {     1 => 2.99,
               50 => 1.99,
              150 => 1.49,
              500 => 1.20 }.collect do |min, price|
              { :fixed => Money.new(95.00*0.8),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]),

        :marginal_price_const => 27.9798139127662,
        :marginal_price_exp => -0.83602431030508,
        :marginal_price_marginal => Money.new(0.792),
        :marginal_price_fixed => Money.new(95.00),
        :marginal => PriceGroup.create_prices(
          {     1 => 2.99,
               50 => 1.99,
              150 => 1.49,
              500 => 1.20 }.collect do |min, price|
              { :fixed => Money.new(95.00*0.8),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]) })

   dec_grp = leeds.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("PhotoGrafixx - Level 4") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 21.3867422708763,
        :fixed_price_exp => -0.71388037968683,
        :fixed_price_marginal => Money.new(0.632),
        :fixed_price_fixed => Money.new(95.0),
        :fixed => PriceGroup.create_prices(
          {     1 => 1.99,
               50 => 1.39,
              150 => 0.99,
              500 => 0.79 }.collect do |min, price|
              { :fixed => Money.new(95.00*0.8),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]),

        :marginal_price_const => 21.3867422708763,
        :marginal_price_exp => -0.71388037968683,
        :marginal_price_marginal => Money.new(0.632),
        :marginal_price_fixed => Money.new(95.00),
        :marginal => PriceGroup.create_prices(
          {     1 => 1.99,
               50 => 1.39,
              150 => 0.99,
              500 => 0.79 }.collect do |min, price|
              { :fixed => Money.new(95.00*0.8),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]) })
        

    # Beach Print (Same in 2014)
    dec_grp = leeds.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Beach Print") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 9.0219391301915,
        :fixed_price_exp => -0.57577751492939,
        :fixed_price_marginal => Money.new(1.032),
        :fixed_price_fixed => Money.new(699.0),
        :fixed => PriceGroup.create_prices(
          {     1 => 2.99,
               50 => 1.99,
              150 => 1.49,
              500 => 1.20 }.collect do |min, price|
              { :fixed => Money.new(699.00*0.8),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]),

        :marginal_price_const => 9.0219391301915,
        :marginal_price_exp => -0.57577751492939,
        :marginal_price_marginal => Money.new(1.032),
        :marginal_price_fixed => Money.new(699.0),
        :marginal => PriceGroup.create_prices(
          {     1 => 2.99,
               50 => 1.99,
              150 => 1.49,
              500 => 1.20 }.collect do |min, price|
              { :fixed => Money.new(699.00*0.8),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]) })


    # Embroidery (Same in 2014)
    dec_grp = leeds.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Embroidery") })
      # <= 7500
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 1.7224412670333,
        :fixed_price_exp => -0.30578466130462,
        :fixed_price_marginal => Money.new(1.592),
        :fixed_price_fixed => Money.new(10.00),
        :fixed => emb_fixed_grp = PriceGroup.create_prices(
          {     1 => 2.79,
               50 => 2.59,
              150 => 2.29,
              500 => 1.99 }.collect do |min, price|
              { :fixed => Money.new(8.00),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]),

        :fixed_divisor => 1000,
        :fixed_offset => 0,
        :marginal_divisor => 1000,
        :marginal_offset => 0,

        :marginal => PriceGroup.create_prices([
          { :fixed => Money.new(8.00),
            :marginal => Money.new(0),
            :minimum => 1},
          { :minimum => 15000 }]) })

      # > 7500
      dec_grp.entries.create({ :minimum => 7500,
       :fixed_price_const => 1.7224412670333,
        :fixed_price_exp => -0.30578466130462,
        :fixed_price_marginal => Money.new(1.592),
        :fixed_price_fixed => Money.new(10.00),
        :fixed => emb_fixed_grp,

        :fixed_divisor => 1000,
        :fixed_offset => 0,
        :marginal_divisor => 1000,
        :marginal_offset => 6500,

        :marginal_price_const => 0,
        :marginal_price_exp => 0,
        :marginal_price_marginal => Money.new(0.38),
        :marginal_price_fixed => Money.new(10.00),

        :marginal => PriceGroup.create_prices([
          { :fixed => Money.new(8.00),
            :marginal => Money.new(0.39*0.8),
            :minimum => 1},
          { :minimum => 15000 }]) })           

  # Dome (Same in 2014)
    dec_grp = leeds.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Dome") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 10.0052674141002,
        :fixed_price_exp => -0.54467100941339,
        :fixed_price_marginal => Money.new(0.472),
        :fixed_price_fixed => Money.new(0),
        :fixed => PriceGroup.create_prices(
          {     1 => 1.29,
               50 => 0.99,
              150 => 0.79,
              500 => 0.59 }.collect do |min, price|
              { :fixed => Money.new(0),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]),

        :marginal_price_const => 10.0052674141002,
        :marginal_price_exp => -0.54467100941339,
        :marginal_price_marginal => Money.new(0.472),
        :marginal_price_fixed => Money.new(0),
        :marginal => PriceGroup.create_prices(
          {     1 => 1.29,
               50 => 0.99,
              150 => 0.79,
              500 => 0.59 }.collect do |min, price|
              { :fixed => Money.new(0),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]) })
end
