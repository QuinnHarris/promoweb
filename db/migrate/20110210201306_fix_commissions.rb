class FixCommissions < ActiveRecord::Migration
  def self.up
    add_column :orders, :commission, :float
    add_column :orders, :payed, :integer, { :null => false, :default => 0 }
    add_column :orders, :settled, :boolean, { :null => false, :default => false }
    remove_column :commissions, :settled
  end

  def self.down
  end
end
