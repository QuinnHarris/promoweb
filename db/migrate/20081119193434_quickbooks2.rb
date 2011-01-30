class Quickbooks2 < ActiveRecord::Migration
  @@tables = %w(orders)
  
  def self.up
    @@tables.each do |table|
      add_column table, :quickbooks_id, :string, :size => 32, :references => nil
      add_column table, :quickbooks_at, :datetime
      add_column table, :quickbooks_sequence, :string, :size => 16
    end
    
    add_column :purchase_orders, :comment, :text
  end

  def self.down
    @@tables.each do |table|
      remove_column table, :quickbooks_id
      remove_column table, :quickbooks_at
      remove_column table, :quickbooks_sequence
    end
    
    remove_column :purchase_orders, :comment
  end
end
