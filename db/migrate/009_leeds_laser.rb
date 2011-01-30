class LeedsLaser < ActiveRecord::Migration
  def self.up
    leeds = Supplier.find_by_name("Leeds")
  
    # Laster Engrave
    dec_grp = leeds.decoration_price_groups.create(
      { :technique => DecorationTechnique.find_by_name("Laser Engrave") })
      dec_grp.entries.create({ :minimum => 1,
        :fixed_price_const => 0.0,
        :fixed_price_exp => 0.0,
        :fixed_price_marginal => 0,
        :fixed_price_fixed => 0,
        :fixed => PriceGroup.create_prices([
        { :fixed => Money.new(0),
          :marginal => Money.new(0),
          :minimum => 1 }]),

        :marginal_price_const => 3.14542149841293,
        :marginal_price_exp => -0.296394439246245,
        :marginal_price_marginal => 52,
        :marginal_price_fixed => 0,
        :marginal => PriceGroup.create_prices([
        { :fixed => Money.new(0),
          :marginal => Money.new(92),
          :minimum => 1 },
        { :fixed => Money.new(0),
          :marginal => Money.new(80),
          :minimum => 100 },
        { :fixed => Money.new(0),
          :marginal => Money.new(72),
          :minimum => 300 },
        { :fixed => Money.new(0),
          :marginal => Money.new(52),
          :minimum => 1200 },
        { :minimum => 2500 }]) })  
  end

  def self.down
  end
end
