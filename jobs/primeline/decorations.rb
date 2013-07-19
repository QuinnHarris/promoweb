require '../generic_import'

apply_decorations('Prime Line') do |primeline|
    # Blank Bag Costs
    dec_grp = primeline.decoration_price_groups.create(
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
  ['Screen Print', 'Pad Print', 'Heat Transfer'].each do |name|
    dec_grp = primeline.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name(name) })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => Money.new(0),
        :fixed_price_fixed => Money.new(56.00),
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(44.80),
          :marginal => Money.new(0),
          :minimum => 1 }]),
          
        :marginal_price_const => 0.0,
        :marginal_price_exp => 0.0,
        :marginal_price_marginal => Money.new(0.55),
        :marginal_price_fixed => Money.new(56.00),
        :marginal => PriceGroup.create_prices([
        { :fixed => Money.new(44.80),
          :marginal => Money.new(0.55*0.8),
          :minimum => 1 }]) })
  end

  # Deboss
    dec_grp = primeline.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Deboss") })
      dec_grp.entries.create({ :minimum => 0,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => Money.new(0),
        :fixed_price_fixed => Money.new(80.00),
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(80.00*0.8),
          :marginal => Money.new(0),
          :minimum => 0 }]) })

  # Laser Engrave
    dec_grp = primeline.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Laser Engrave") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => Money.new(0),
        :fixed_price_fixed => Money.new(80.00),
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(80.00*0.8),
          :marginal => Money.new(0),
          :minimum => 1 }]),
          
        :marginal_price_const => 0.0,
        :marginal_price_exp => 0.0,
        :marginal_price_marginal => Money.new(0.55),
        :marginal_price_fixed => Money.new(80.00),
        :marginal => PriceGroup.create_prices([
        { :fixed => Money.new(80.00*0.8),
          :marginal => Money.new(0.55*0.8),
          :minimum => 1 }]) })

  # Image Bonding
    dec_grp = primeline.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Image Bonding") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => Money.new(0),
        :fixed_price_fixed => Money.new(80.00),
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(80.00*0.8),
          :marginal => Money.new(0),
          :minimum => 1 }]),
          
        :marginal_price_const => 0.0,
        :marginal_price_exp => 0.0,
        :marginal_price_marginal => Money.new(0.75),
        :marginal_price_fixed => Money.new(80.00),
        :marginal => PriceGroup.create_prices([
        { :fixed => Money.new(80.00*0.8),
          :marginal => Money.new(0.75*0.8),
          :minimum => 1 }]) })

  # Four Color
    dec_grp = primeline.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("4 Color Photographic") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => Money.new(0),
        :fixed_price_fixed => Money.new(150.00),
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(150.00*0.8),
          :marginal => Money.new(0),
          :minimum => 1 }]) })

  # Embroidery
  dec_grp = primeline.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Embroidery") })
      # <= 7500
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_fixed => Money.new(50.00),
        :fixed_price_marginal => Money.new(2.25),
        :fixed => emb_fixed_grp = PriceGroup.create_prices(
          {     1 => 2.25 }.collect do |min, price|
              { :fixed => Money.new(16.00),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]),

        :fixed_divisor => 7500,
        :fixed_offset => 0,
        :marginal_divisor => 7500,
        :marginal_offset => 0,

        :marginal => PriceGroup.create_prices([
          { :fixed => Money.new(1600),
            :marginal => Money.new(0),
            :minimum => 1},
          { :minimum => 15000 }]) })

      # > 7500
      dec_grp.entries.create({ :minimum => 7500,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_fixed => Money.new(50.00),
        :fixed_price_marginal => Money.new(2.25),
        :fixed => emb_fixed_grp,

        :fixed_divisor => 1000,
        :fixed_offset => 0,
        :marginal_divisor => 1000,
        :marginal_offset => 6500,

        :marginal_price_const => 0.0,
        :marginal_price_exp => 0.0,
        :marginal_price_marginal => Money.new(0.35),
        :marginal_price_fixed => Money.new(20.00),
        :marginal => PriceGroup.create_prices([
          { :fixed => Money.new(16.00),
            :marginal => Money.new(0.28),
            :minimum => 1},
          { :minimum => 15000 }]) })    
end
