class Payment < ActiveRecord::Migration
  def self.up
    change_column :payment_methods, :billing_id, :string, :size => 6, :null => true
    add_column :payment_transactions, :number, :string, :size => 16
    add_column :payment_transactions, :data, :text
    add_column :payment_transactions, :quickbooks_id, :string, :size => 32, :references => nil
    add_column :payment_transactions, :quickbooks_at, :datetime
    add_column :payment_transactions, :quickbooks_sequence, :string, :size => 16
  end

  def self.down
    remove_column :payment_transactions, :data
    remove_column :payment_transactions, :quickbooks_id
    remove_column :payment_transactions, :quickbooks_at
    remove_column :payment_transactions, :quickbooks_sequence
  end
end
