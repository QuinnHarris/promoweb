class ProductDeleted < ActiveRecord::Migration
  def self.up
    add_column :products, :deleted, :boolean, { :null => false, :default => false }
    add_column :variants, :deleted, :boolean, { :null => false, :default => false }
  end

  def self.down
    remove_column :products, :deleted
    remove_column :variants, :deleted
  end
end
