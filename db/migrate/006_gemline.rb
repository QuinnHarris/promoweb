class Gemline < ActiveRecord::Migration
  def self.up
    gemline = Supplier.create({
      :name => "Gemline",
      :price_source => PriceSource.new({:name => "Gemline"})
    })
    
    gemline.warehouses.create({:postalcode => '01843'})    

    # Blank Bag Costs
    dec_grp = gemline.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("None") })
      dec_grp.entries.create({ :minimum => 0,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => -31,
        :fixed_price_fixed => 0,      
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(0),
          :marginal => Money.new(-31),
          :minimum => 0 }]) })
    
    
    # Screen Print Costs
    dec_grp = gemline.decoration_price_groups.create(
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
          
        :marginal_price_const => 16.6954093767187,
        :marginal_price_exp => -0.576560516885374,
        :marginal_price_marginal => 36,
        :marginal_price_fixed => 5000,
        :marginal => PriceGroup.create_prices([
        { :fixed => Money.new(4400),
          :marginal => Money.new(79),
          :minimum => 25 },
        { :fixed => Money.new(4400),
          :marginal => Money.new(59),
          :minimum => 100 },
        { :fixed => Money.new(4400),
          :marginal => Money.new(47),
          :minimum => 300 },
        { :fixed => Money.new(4400),
          :marginal => Money.new(36),
          :minimum => 1000 }]) })     
        
    
    # Embroidery
    dec_grp = gemline.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Embroidery") })
      # <= 5000
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.941286178930541,
        :fixed_price_exp => -0.200474815775463,
        :fixed_price_marginal => 159,
        :fixed_price_fixed => 9000,
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(8000),
          :marginal => Money.new(200),  # 224
          :minimum => 6 },
        { :fixed => Money.new(8000),
          :marginal => Money.new(180),  # 204
          :minimum => 100 },
        { :fixed => Money.new(8000),
          :marginal => Money.new(158),  # 183
          :minimum => 300 }]) })
            
      # 5001 - 7500
      dec_grp.entries.create({ :minimum => 5001,
        :fixed_price_const => 0.760356986083937,
        :fixed_price_exp => -0.163050672252103,
        :fixed_price_marginal => 198,
        :fixed_price_fixed => 9000,
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(10000),
          :marginal => Money.new(239),  # 264
          :minimum => 6 },
        { :fixed => Money.new(10000),
          :marginal => Money.new(219),  # 244
          :minimum => 100 },
        { :fixed => Money.new(10000),
          :marginal => Money.new(198),  # 223
          :minimum => 300 }]),
        :fixed_divisor => 1000,
        :fixed_offset => 0,
        :marginal_divisor => 1000,
        :marginal_offset => 2500,
        
        :marginal_price_const => 0.0,
        :marginal_price_exp => 0.0,
        :marginal_price_marginal => 27,
        :marginal_price_fixed => 2300,
        :marginal => PriceGroup.create_prices([
        { :fixed => Money.new(2000),
          :marginal => Money.new(24),
          :minimum => 6 }]) })

        
    # Deboss
    dec_grp = gemline.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Deboss") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => 0,
        :fixed_price_fixed => 6300,
        
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(5600),
          :marginal => Money.new(0),
          :minimum => 1 }]),
        :marginal_divisor => 12,
        
        :marginal_price_const => 0.0,
        :marginal_price_exp => 0.0,
        :marginal_price_marginal => 0,
        :marginal_price_fixed => 2700,
        :marginal => PriceGroup.create_prices([
        { :fixed => Money.new(2400),
          :marginal => Money.new(0),
          :minimum => 1 }]) })
          
      dec_grp.entries.create({ :minimum => 25,
        :fixed_price_marginal => nil,
        :fixed_price_fixed => nil,
        :fixed => PriceGroup.create_prices([
        { :minimum => 1 }]) })
        
        
    # Personalization
    dec_grp = gemline.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Personalization") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => 0,
        :fixed_price_fixed => 0,
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(0),
          :marginal => Money.new(0),
          :minimum => 1 }]),
          
        :marginal_divisor => 25,
        :marginal_price_const => 0.0,
        :marginal_price_exp => 0.0,
        :marginal_price_marginal => 0,
        :marginal_price_fixed => 2700,
        :marginal => PriceGroup.create_prices([
        { :fixed => Money.new(2400),
          :marginal => Money.new(0),
          :minimum => 1 }])   
        })


    # Photo
    dec_grp = gemline.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Photo Transfer") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => 181,
        :fixed_price_fixed => 0,
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(0),
          :marginal => Money.new(141),
          :minimum => 1 }]),
        })        
    
    
    # Patch
    dec_grp = gemline.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Patch") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => 40,
        :fixed_price_fixed => 27000,
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(24000),
          :marginal => Money.new(35),
          :minimum => 1 }]),
        })
        
        
    # LogoMagic
    dec_grp = gemline.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("LogoMagic") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => 0,
        :fixed_price_fixed => 4950,
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(4400),
          :marginal => Money.new(0),
          :minimum => 1 }]),
        })
  end

  def self.down
  end
end
