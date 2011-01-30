class Leeds < ActiveRecord::Migration
  def self.up
    leeds = Supplier.create({
      :name => "Leeds",
      :price_source => PriceSource.new({:name => "Leeds"})
    })
    
    leeds.warehouses.create({:postalcode => '15068', :city => 'New Kensington'})
    
#    # Blank Bag Costs
    dec_grp = leeds.decoration_price_groups.create(
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
    
    
    # Screen Print Costs
    dec_grp = leeds.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Screen Print") })  
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => 0,
        :fixed_price_fixed => 5000,
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(4400),
          :marginal => Money.new(0),
          :minimum => 1 }]),

        :marginal_price_const => 29.372958454211,
        :marginal_price_exp => -0.785213457768842,
        :marginal_price_marginal => 29,
        :marginal_price_fixed => 5000,
        :marginal => PriceGroup.create_prices([
        { :fixed => Money.new(4400),
          :marginal => Money.new(68),
          :minimum => 1 },
        { :fixed => Money.new(4400),
          :marginal => Money.new(48),
          :minimum => 100 },
        { :fixed => Money.new(4400),
          :marginal => Money.new(36),
          :minimum => 300 },
        { :minimum => 2500 }]) })     
        
    
#    # Embroidery
    dec_grp = leeds.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Embroidery") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.973684210526316,
        :fixed_price_exp => -0.166049618997522,
        :fixed_price_marginal => 152,
        :fixed_price_fixed => 3600,
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(3200),
          :marginal => Money.new(204),
          :minimum => 1 },
        { :fixed => Money.new(3200),
          :marginal => Money.new(168),
          :minimum => 300 },
        { :fixed => Money.new(3200),
          :marginal => Money.new(160),
          :minimum => 1200 }]),
        :marginal_divisor => 1000,
        :marginal_offset => 7500,
        :marginal_price_const => 0.0,
        :marginal_price_exp => 0.0,
        :marginal_price_marginal => 27,
        :marginal_price_fixed => 0,
        :marginal => PriceGroup.create_prices([
        { :fixed => Money.new(0),
          :marginal => Money.new(24),
          :minimum => 1 }]), })

        
    # Deboss
    dec_grp = leeds.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Deboss") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => 0,
        :fixed_price_fixed => 5625,
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(5000),
          :marginal => Money.new(0),
          :minimum => 1 }]),

        :marginal_price_const => 1.62665947436704,
        :marginal_price_exp => -0.385320956616481,
        :marginal_price_marginal => 85,
        :marginal_price_fixed => 5625,
        :marginal => PriceGroup.create_prices([
        { :fixed => Money.new(5000),
          :marginal => Money.new(100),
          :minimum => 1 },
        { :fixed => Money.new(5000),
          :marginal => Money.new(92),
          :minimum => 100 },
        { :fixed => Money.new(5000),
          :marginal => Money.new(80),
          :minimum => 300 },
        { :fixed => Money.new(5000),
          :marginal => Money.new(76),
          :minimum => 1200 },
        { :minimum => 2500 }]) })  
  end

  def self.down
  end
end
