class Lanco < ActiveRecord::Migration
  def self.up
    lanco = Supplier.create({
      :name => "Lanco",
      :price_source => PriceSource.create({:name => "Lanco"})
    })
    
    lanco.warehouses.create({:postalcode => '11788'})
  end

  def self.down
  end
end
