class PriceCache < ActiveRecord::Migration
  def self.up
    add_column :products, :price_fullstring_cache, :string
    add_column :products, :price_shortstring_cache, :string, :limit => 12
  end

  def self.down
    remove_column :products, :price_fullstring_cache
    remove_column :products, :price_shortstring_cache
  end
end
