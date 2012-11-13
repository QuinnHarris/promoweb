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
    dec_grp = primeline.decoration_price_groups.create(
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
          
        :marginal_price_const => 0.0,
        :marginal_price_exp => 0.0,
        :marginal_price_marginal => Money.new(0.55),
        :marginal_price_fixed => Money.new(55.00),
        :marginal => PriceGroup.create_prices([
        { :fixed => Money.new(44.00),
          :marginal => Money.new(0.55*0.8),
          :minimum => 1 }]) })

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

  # Pad Print
    dec_grp = primeline.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Pad Print") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => Money.new(0),
        :fixed_price_fixed => Money.new(55.00),
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(44.00),
          :marginal => Money.new(0),
          :minimum => 1 }]),
          
        :marginal_price_const => 0.0,
        :marginal_price_exp => 0.0,
        :marginal_price_marginal => Money.new(0.55),
        :marginal_price_fixed => Money.new(55.00),
        :marginal => PriceGroup.create_prices([
        { :fixed => Money.new(44.00),
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
end
