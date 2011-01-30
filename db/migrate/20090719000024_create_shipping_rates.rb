class CreateShippingRates < ActiveRecord::Migration
  def self.up
    create_table :shipping_rates do |t|
      t.string :type
      t.integer :customer_id, :null => false
#      t.integer :supplier_id, :null => false
      t.integer :product_id, :null => false
      t.integer :quantity

      t.text :data

      t.timestamps
    end
    execute "ALTER TABLE shipping_rates ADD CONSTRAINT unique_shipping_rates UNIQUE(customer_id, product_id, quantity)"

    add_column :order_items, :shipping_type, :string, :length => 16
    add_column :order_items, :shipping_code, :string, :length => 8
    add_column :order_items, :shipping_price, :integer
    add_column :order_items, :shipping_cost, :integer

    OrderItem.update_all("shipping_type = 'NONE', shipping_price = 0, shipping_cost = 0", '')

    InvoiceEntry
    InvoiceOrderItem.find(:all).each do |item|
      item.data = item.data.merge('shipping_type' => 'NONE')
      item.save!
    end
  end

  def self.down
    drop_table :shipping_rates
  end
end
