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
  [['Screen Print', 55.0], ['Laser Engrave', 55.0], ['Deboss', 75.0]].each do |dec_name, dec_setup|
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

        :marginal_price_const => 6.62796797472755,
        :marginal_price_exp => -0.41179228034711,
        :marginal_price_marginal => Money.new(0.312),
        :marginal_price_fixed => Money.new(55.00),
        :marginal => PriceGroup.create_prices(
          {     1 => 0.99,
               50 => 0.69,
              150 => 0.59,
              500 => 0.39 }.collect do |min, price|
              { :fixed => Money.new(44.00),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]) })
  end


    # Photo Real
    dec_grp = leeds.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Photo Transfer") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 15.3495506560675,
        :fixed_price_exp => -0.63157782545505,
        :fixed_price_marginal => Money.new(0.792),
        :fixed_price_fixed => Money.new(95.0),
        :fixed => PriceGroup.create_prices(
          {     1 => 2.99,
               50 => 1.49,
              150 => 1.29,
              500 => 1.70 }.collect do |min, price|
              { :fixed => Money.new(95.00*0.8),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]),

        :marginal_price_const => 15.3495506560675,
        :marginal_price_exp => -0.63157782545505,
        :marginal_price_marginal => Money.new(0.792),
        :marginal_price_fixed => Money.new(95.00),
        :marginal => PriceGroup.create_prices(
          {     1 => 2.99,
               50 => 1.49,
              150 => 1.29,
              500 => 1.70 }.collect do |min, price|
              { :fixed => Money.new(95.00*0.8),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]) })
        

    # Beach Print
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


    # Embroidery
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

  # Dome
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
