class NewPricing < ActiveRecord::Migration
  def self.up
    add_column :price_groups, :coefficient, :float, :references => nil
    add_column :price_groups, :exponent, :float, :references => nil
  end

  def self.down
  end
end
