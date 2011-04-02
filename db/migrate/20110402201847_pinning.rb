class Pinning < ActiveRecord::Migration
  def self.up
    add_column :categories, :pinned, :boolean, :default => false, :null => false
    add_column :categories_products, :pinned, :boolean
  end

  def self.down
  end
end
