require '../generic_import'

norwood = Supplier.find_by_name("Norwood")

# Remove all old records
norwood.decoration_price_groups.each do |grp|
  grp.entries.each do |entry|
    fixed = entry.fixed
    marginal = entry.marginal

    entry.destroy
    
    fixed.destroy if fixed and fixed.decoration_price_entry_fixed.empty?
    marginal.destroy if marginal and marginal.decoration_price_entry_marginal.empty?
  end
  grp.destroy
end

dec_grp = norwood.decoration_price_groups.create(
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
dec_grp = norwood.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Screen Print") })  
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => Money.new(0),
        :fixed_price_fixed => Money.new(55.0),
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(44.0),
          :marginal => Money.new(0),
          :minimum => 1 }]),

        :marginal_price_const => 29.372958454211,
        :marginal_price_exp => -0.785213457768842,
        :marginal_price_marginal => Money.new(0.29),
        :marginal_price_fixed => Money.new(55.0),
        :marginal => PriceGroup.create_prices(
          {     1 => 0.85,
              100 => 0.60,
              300 => 0.45,
             2500 => 0.40,
            10000 => 0.35 }.collect do |min, price|
              { :fixed => Money.new(4400),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]) })


# Pad Print
dec_grp = norwood.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Pad Print") })  
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => Money.new(0),
        :fixed_price_fixed => Money.new(50.0),
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(40.0),
          :marginal => Money.new(0),
          :minimum => 1 }]),

        :marginal_price_const => 0.0,
        :marginal_price_exp => 0.0,
        :marginal_price_marginal => Money.new(0.35),
        :marginal_price_fixed => Money.new(50.0),
        :marginal => PriceGroup.create_prices(
          {     1 => 0.35 }.collect do |min, price|
              { :fixed => Money.new(4400),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]) })

    


# Embroidery
dec_grp = norwood.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Embroidery") })
      # <= 10000
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_fixed => Money.new(20.00),
        :fixed_price_marginal => Money.new(1.50),
        :fixed => emb_fixed_grp = PriceGroup.create_prices(
          {     1 => 1.50 }.collect do |min, price|
              { :fixed => Money.new(16.00),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]),

        :fixed_divisor => 10000,
        :fixed_offset => 0,
        :marginal_divisor => 10000,
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
        :fixed_price_fixed => Money.new(20.00),
        :fixed_price_marginal => Money.new(0.30),
        :fixed => emb_fixed_grp,

        :fixed_divisor => 1000,
        :fixed_offset => 0,
        :marginal_divisor => 1000,
        :marginal_offset => 9000,

        :marginal => PriceGroup.create_prices([
          { :fixed => Money.new(16.00),
            :marginal => Money.new(0.32),
            :minimum => 1},
          { :minimum => 15000 }]) })           


        
# Deboss
dec_grp = norwood.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Deboss") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => Money.new(0),
        :fixed_price_fixed => Money.new(56.25),
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(50.0),
          :marginal => Money.new(0),
          :minimum => 1 }]),

        :marginal_price_const => 1.62665947436704,
        :marginal_price_exp => -0.385320956616481,
        :marginal_price_marginal => Money.new(0.85),
        :marginal_price_fixed => Money.new(56.25),
        :marginal => PriceGroup.create_prices([
        { :fixed => Money.new(50.00),
          :marginal => Money.new(100.0),
          :minimum => 1 },
        { :fixed => Money.new(50.00),
          :marginal => Money.new(0.92),
          :minimum => 100 },
        { :fixed => Money.new(50.00),
          :marginal => Money.new(0.80),
          :minimum => 300 },
        { :fixed => Money.new(50.00),
          :marginal => Money.new(0.76),
          :minimum => 1200 },
        { :minimum => 2500 }]) })

# Laser Engrave
dec_grp = norwood.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("Laser Engrave") })  
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => Money.new(0),
        :fixed_price_fixed => Money.new(20.00),
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(16.00),
          :marginal => Money.new(0),
          :minimum => 1 }]),

        :marginal_price_const => 29.372958454211,
        :marginal_price_exp => -0.785213457768842,
        :marginal_price_marginal => Money.new(0.29),
        :marginal_price_fixed => Money.new(20.00),
        :marginal => PriceGroup.create_prices(
          {     1 => 0.85,
              100 => 0.60,
              300 => 0.45,
             2500 => 0.40,
            10000 => 0.35 }.collect do |min, price|
              { :fixed => Money.new(16.00),
                :marginal => Money.new(price*0.8),
                :minimum => min }
          end + [{ :minimum => 15000 }]) })
