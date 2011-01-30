class CreateCommissions < ActiveRecord::Migration
  def self.up
    add_column :orders, :total_price_cache, :integer
    add_column :orders, :total_cost_cache, :integer
    add_column :order_items, :product_id, :integer
    add_foreign_key :order_items, :products

    Order.find(:all, :order => 'id').each do |order|
      Rails.logger.info("Order: #{order.id}")
      order.items.each do |item|
        id = item.price_group.variants.first.product_id
        OrderItem.update_all("product_id = #{id}", "id = #{item.id}")
      end
      Order.update_all("total_price_cache = #{order.total_item_price.min.units}, total_cost_cache = #{order.total_item_cost.min.units}", "id = #{order.id}")
    end

    change_column :orders, :total_price_cache, :integer, :null => false
    change_column :orders, :total_cost_cache, :integer, :null => false
    change_column :order_items, :product_id, :integer, :null => false

    add_column :users, :commission, :float

    create_table :commissions do |t|
      t.column :user_id, :integer, :null => false
      t.column :settled, :integer, :null => false
      t.column :payed, :integer, :null => false
      t.column :comment, :text

      t.column :quickbooks_at, :datetime
      t.column :quickbooks_id, :string, :size => 32
      t.column :quickbooks_sequence, :string, :size => 16
      t.column :quickbooks_ref, :string, :size => 16
      t.timestamps
    end
    add_foreign_key :commissions, :users
  end

  def self.down
    drop_table :commissions
  end
end
