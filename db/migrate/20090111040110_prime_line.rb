class PrimeLine < ActiveRecord::Migration
  def self.up
    primeline = Supplier.find_by_name("PrimeLine")

    # Blank Bag Costs
    dec_grp = primeline.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("None") })
      dec_grp.entries.create({ :minimum => 0,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => 0,
        :fixed_price_fixed => 0,    
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
        :fixed_price_marginal => 0,
        :fixed_price_fixed => 5000,
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(3500),
          :marginal => Money.new(0),
          :minimum => 1 }]),
          
        :marginal_price_const => 0.0,
        :marginal_price_exp => 0.0,
        :marginal_price_marginal => 70,
        :marginal_price_fixed => 5000,
        :marginal => PriceGroup.create_prices([
        { :fixed => Money.new(3500),
          :marginal => Money.new(49),
          :minimum => 1 }]) })

  # Deboss
    dec_grp = primeline.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Deboss") })
      dec_grp.entries.create({ :minimum => 0,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => 0,
        :fixed_price_fixed => 6500,    
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(3550),
          :marginal => Money.new(0),
          :minimum => 0 }]) })

  # Laser Engrave
    dec_grp = primeline.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Laser Engrave") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => 0,
        :fixed_price_fixed => 6000,
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(4200),
          :marginal => Money.new(0),
          :minimum => 1 }]),
          
        :marginal_price_const => 0.0,
        :marginal_price_exp => 0.0,
        :marginal_price_marginal => 70,
        :marginal_price_fixed => 6000,
        :marginal => PriceGroup.create_prices([
        { :fixed => Money.new(4200),
          :marginal => Money.new(49),
          :minimum => 1 }]) })

  # Pad Print
    dec_grp = primeline.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Pad Print") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => 0,
        :fixed_price_fixed => 5000,
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(3500),
          :marginal => Money.new(0),
          :minimum => 1 }]),
          
        :marginal_price_const => 0.0,
        :marginal_price_exp => 0.0,
        :marginal_price_marginal => 70,
        :marginal_price_fixed => 5000,
        :marginal => PriceGroup.create_prices([
        { :fixed => Money.new(3500),
          :marginal => Money.new(49),
          :minimum => 1 }]) })

  # Image Bonding
    dec_grp = primeline.decoration_price_groups.create(
      { :technique => DecorationTechnique.create({:name => "Image Bonding"}) })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => 0,
        :fixed_price_fixed => 6500,
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(4550),
          :marginal => Money.new(0),
          :minimum => 1 }]),
          
        :marginal_price_const => 0.0,
        :marginal_price_exp => 0.0,
        :marginal_price_marginal => 70,
        :marginal_price_fixed => 6500,
        :marginal => PriceGroup.create_prices([
        { :fixed => Money.new(4550),
          :marginal => Money.new(49),
          :minimum => 1 }]) })

  # Four Color
    dec_grp = primeline.decoration_price_groups.create(
      { :technique => DecorationTechnique.create({:name => "Four Color"}) })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => 0,
        :fixed_price_fixed => 20000,
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(14000),
          :marginal => Money.new(0),
          :minimum => 1 }]),
          
        :marginal_price_const => 0.0,
        :marginal_price_exp => 0.0,
        :marginal_price_marginal => 75,
        :marginal_price_fixed => 20000,
        :marginal => PriceGroup.create_prices([
        { :fixed => Money.new(14000),
          :marginal => Money.new(53),
          :minimum => 1 }]) })
  end

  def self.down
  end
end
