class UpdateCustomers < ActiveRecord::Migration
  def self.up
    [:order_items, :order_item_entries, :order_item_decorations].each do |table|
      add_column table, :marginal_cost, :integer
      add_column table, :fixed_cost, :integer
    end
    
    add_column :order_entries, :cost, :integer
  end

  def self.down
  end
end
