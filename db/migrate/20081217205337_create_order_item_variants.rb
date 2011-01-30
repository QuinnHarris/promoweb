class CreateOrderItemVariants < ActiveRecord::Migration
  def self.up
    create_table :order_item_variants do |t|
      t.integer :order_item_id, :null => false
      t.integer :variant_id
      t.integer :quantity, :null => false
      t.string :imprint_colors, :null => false, :default => ''

      t.timestamps
    end
    execute "ALTER TABLE order_item_variants ADD CONSTRAINT order_item_variants_pair UNIQUE(order_item_id, variant_id)"
    

    OrderItem.find(:all).each do |item|
      item.order_item_variants.create(:variant_id => item.variant_id, :quantity => item['quantity'])
    end

    remove_column :order_items, :variant_id
    remove_column :order_items, :quantity

    InvoiceEntry
    InvoiceOrderItem.find(:all).each do |item|
      attr = item.data
      attr['order_item_variants'] = [{'quantity' => attr.delete('quantity'), 'variant_id' => attr.delete('variant_id') }]
      item.data = attr
      item.save!
    end

    change_column :purchase_order_entries, :price, :integer, :null => true, :default => nil
  end

  def self.down
    drop_table :order_item_variants
  end
end
