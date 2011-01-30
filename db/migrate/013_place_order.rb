class PlaceOrder < ActiveRecord::Migration
  def self.up
    add_column :orders, :process_order, :boolean
    OrderState.create(:name => 'order_submit')
    OrderState.create(:name => 'order_reviewed')
  end

  def self.down
    remove_column :orders, :process_order
  end
end
