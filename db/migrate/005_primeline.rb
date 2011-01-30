class Primeline < ActiveRecord::Migration
  def self.up 
    primeline = Supplier.create({
      :name => "PrimeLine",
      :price_source => PriceSource.create({:name => "PrimeLine"})
    })
    
    primeline.warehouses.create({:postalcode => '06610'})
  
#  #    # Blank Bag Costs
#    dec_grp = leeds.decoration_price_groups.create(
#      { :technique => DecorationTechnique.find_by_name("None") })
#      dec_grp.entries.create({ :minimum => 0,
#        :fixed_price_const => 0.0,
#        :fixed_price_exp => 0.0,
#        :fixed_price_marginal => 0,
#        :fixed_price_fixed => 0,    
#        :fixed => PriceGroup.create_prices([
#        { :fixed => Money.new(0),
#          :marginal => Money.new(0),
#          :minimum => 0 }]) })
#          
#  # Screen Print
#    dec_grp = leeds.decoration_price_groups.create(
#      { :technique => DecorationTechnique.find_by_name("Screen Print") })
#      dec_grp.entries.create({ :minimum => 1,
#        :fixed_price_const => 0.0,
#        :fixed_price_exp => 0.0,
#        :fixed_price_marginal => 0,
#        :fixed_price_fixed => 5850,
#        :fixed => PriceGroup.create_prices([
#        { :fixed => Money.new(5200),
#          :marginal => Money.new(0),
#          :minimum => 1 }]),
#          
#        :marginal_price_const => 16.6954093767187,
#        :marginal_price_exp => -0.576560516885374,
#        :marginal_price_marginal => 0.45,
#        :marginal_price_fixed => 5850,
#        :marginal => PriceGroup.create_prices([
#        { :fixed => Money.new(5850),
#          :marginal => Money.new(40),
#          :minimum => 1 })  })
  end

  def self.down
  end
end
