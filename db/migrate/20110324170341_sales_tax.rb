class SalesTax < ActiveRecord::Migration
  def self.up
    add_column :orders, :tax_rate, :float, :null => false, :default => 0.0
    add_column :orders, :tax_type, :string
    add_column :invoices, :tax_rate, :float, :null => false, :default => 0.0
  end

  def self.down
  end
end
