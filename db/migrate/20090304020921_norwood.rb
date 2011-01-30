class Norwood < ActiveRecord::Migration
  def self.up
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
        :fixed_price_marginal => 0,
        :fixed_price_fixed => 0,   
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
        :fixed_price_marginal => 0,
        :fixed_price_fixed => 5500,
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(4400),
          :marginal => Money.new(0),
          :minimum => 1 }]),

        :marginal_price_const => 29.372958454211,
        :marginal_price_exp => -0.785213457768842,
        :marginal_price_marginal => 29,
        :marginal_price_fixed => 5500,
        :marginal => PriceGroup.create_prices(
          {     1 => 0.85,
              100 => 0.60,
              300 => 0.45,
             2500 => 0.40,
            10000 => 0.35 }.collect do |min, price|
              { :fixed => Money.new(4400),
                :marginal => Money.new((price*100.0*0.8).to_i),
                :minimum => min }
          end + [{ :minimum => 15000 }]) })


    # Photo Real
    dec_grp = norwood.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Photo Transfer") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 10.0814,
        :fixed_price_exp => -0.56110793913641,
        :fixed_price_marginal => 128,
        :fixed_price_fixed => 18000,
        :fixed => PriceGroup.create_prices(
          {     1 => 3.40,
              100 => 2.40,
              300 => 1.80,
             2500 => 1.60,
            10000 => 1.40 }.collect do |min, price|
              { :fixed => Money.new(14400),
                :marginal => Money.new((price*100.0*0.8).to_i),
                :minimum => min }
          end + [{ :minimum => 15000 }]),

        :marginal_price_const => 10.0814,
        :marginal_price_exp => -0.56110793913641,
        :marginal_price_marginal => 128,
        :marginal_price_fixed => 18000,
        :marginal => PriceGroup.create_prices(
          {     1 => 3.91,
              100 => 2.76,
              300 => 2.07,
             2500 => 1.84,
            10000 => 1.61 }.collect do |min, price|
              { :fixed => Money.new(14400),
                :marginal => Money.new((price*100.0*0.8).to_i),
                :minimum => min }
          end + [{ :minimum => 15000 }]) })
        


    # Embroidery
    dec_grp = norwood.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Embroidery") })
      # <= 7500
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 1.00534759358289,
        :fixed_price_exp => -0.17056319392749,
        :fixed_price_marginal => 150,
        :fixed_price_fixed => 2000,
        :fixed => emb_fixed_grp = PriceGroup.create_prices(
          {     1 => 2.55,
              300 => 2.10,
             1200 => 2.00,
             2500 => 1.90,
             5000 => 1.85,
            10000 => 1.80 }.collect do |min, price|
              { :fixed => Money.new(1600),
                :marginal => Money.new((price*100.0*0.8).to_i),
                :minimum => min }
          end + [{ :minimum => 15000 }]),

        :fixed_divisor => 1000,
        :fixed_offset => 0,
        :marginal_divisor => 1000,
        :marginal_offset => 0,

        :marginal => PriceGroup.create_prices([
          { :fixed => Money.new(1600),
            :marginal => Money.new(0),
            :minimum => 1},
          { :minimum => 15000 }]) })

      # > 7500
      dec_grp.entries.create({ :minimum => 7500,
        :fixed_price_const => 0,
        :fixed_price_exp => 0,
        :fixed_price_marginal => 30,
        :fixed_price_fixed => 2000,
        :fixed => emb_fixed_grp,

        :fixed_divisor => 1000,
        :fixed_offset => 0,
        :marginal_divisor => 1000,
        :marginal_offset => 6500,

        :marginal => PriceGroup.create_prices([
          { :fixed => Money.new(1600),
            :marginal => Money.new(24),
            :minimum => 1},
          { :minimum => 15000 }]) })           


        
    # Deboss
    dec_grp = norwood.decoration_price_groups.create(
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

   # Laser Engrave
    dec_grp = norwood.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Laser Engrave") })  
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => 0,
        :fixed_price_fixed => 2000,
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(1600),
          :marginal => Money.new(0),
          :minimum => 1 }]),

        :marginal_price_const => 29.372958454211,
        :marginal_price_exp => -0.785213457768842,
        :marginal_price_marginal => 29,
        :marginal_price_fixed => 2000,
        :marginal => PriceGroup.create_prices(
          {     1 => 0.85,
              100 => 0.60,
              300 => 0.45,
             2500 => 0.40,
            10000 => 0.35 }.collect do |min, price|
              { :fixed => Money.new(1600),
                :marginal => Money.new((price*100.0*0.8).to_i),
                :minimum => min }
          end + [{ :minimum => 15000 }]) })



  # Dome
    dec_grp = norwood.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Dome") || DecorationTechnique.create(:name => "Dome") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 3.17636460716223,
        :fixed_price_exp => -0.2770525557931,
        :fixed_price_marginal => 60,
        :fixed_price_fixed => 0,
        :fixed => PriceGroup.create_prices(
          {     1 => 1.25,
              100 => 1.15,
              300 => 1.00,
             1200 => 0.95,
             2500 => 0.85,
             5000 => 0.78,
            10000 => 0.68 }.collect do |min, price|
              { :fixed => Money.new(0),
                :marginal => Money.new((price*100.0*0.8).to_i),
                :minimum => min }
          end + [{ :minimum => 15000 }]),

        :marginal_price_const => 2.21603786206194,
        :marginal_price_exp => -0.23478317491358,
        :marginal_price_marginal => 75,
        :marginal_price_fixed => 0,
        :marginal => PriceGroup.create_prices(
          {     1 => 1.56,
              100 => 1.44,
              300 => 1.25,
             1200 => 1.19,
             2500 => 1.06,
             5000 => 0.97,
            10000 => 0.86 }.collect do |min, price|
              { :fixed => Money.new(0),
                :marginal => Money.new((price*100.0*0.8).to_i),
                :minimum => min }
          end + [{ :minimum => 15000 }]) })


  # Stamp
    dec_grp = norwood.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Stamp") || DecorationTechnique.create(:name => "Stamp") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 3.17636460716223,
        :fixed_price_exp => -0.2770525557931,
        :fixed_price_marginal => 60,
        :fixed_price_fixed => 7000,
        :fixed => PriceGroup.create_prices(
          {     1 => 1.25,
              100 => 1.15,
              300 => 1.00,
             1200 => 0.95,
             2500 => 0.85,
             5000 => 0.78,
            10000 => 0.68 }.collect do |min, price|
              { :fixed => Money.new(5600),
                :marginal => Money.new((price*100.0*0.8).to_i),
                :minimum => min }
          end + [{ :minimum => 15000 }]),

        :marginal_price_const => 2.21603786206194,
        :marginal_price_exp => -0.23478317491358,
        :marginal_price_marginal => 75,
        :marginal_price_fixed => 7000,
        :marginal => PriceGroup.create_prices(
          {     1 => 1.56,
              100 => 1.44,
              300 => 1.25,
             1200 => 1.19,
             2500 => 1.06,
             5000 => 0.97,
            10000 => 0.86 }.collect do |min, price|
              { :fixed => Money.new(5600),
                :marginal => Money.new((price*100.0*0.8).to_i),
                :minimum => min }
          end + [{ :minimum => 15000 }]) })

  end

  def self.down
  end
end
