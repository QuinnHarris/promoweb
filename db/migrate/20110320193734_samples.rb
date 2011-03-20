class Samples < ActiveRecord::Migration
  def self.up
    add_column :order_items, :sample_requested, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :order_items, :sample_requested
  end
end
