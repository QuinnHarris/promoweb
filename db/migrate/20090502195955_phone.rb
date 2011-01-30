class Phone < ActiveRecord::Migration
  def self.up
    add_column :users, :current_order_id, :integer, :references => :orders

    add_column :suppliers, :phone, :string
  end

  def self.down
    remove_column :users, :current_order_id
    remove_column :suppliers, :phone
  end
end
