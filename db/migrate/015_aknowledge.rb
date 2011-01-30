class Aknowledge < ActiveRecord::Migration
  def self.up
    add_column :orders, :our_comments, :text
    add_column :orders, :terms, :string
    add_column :orders, :rush, :boolean
    add_column :orders, :ship_method, :string
    add_column :orders, :fob, :string
    add_column :orders, :closed, :boolean, :default => false

    add_column :order_items, :ship_date, :date
    add_column :order_items, :ship_tracking, :string
    
    create_table :artwork_order_tags do |t|
      t.column :artwork_id,  :integer, :null => false
      t.column :order_id, :integer, :null => false
      t.column :name, :string, :null => false
    end
  end

  def self.down
    remove_column :orders, :our_comments
    remove_column :orders, :terms
    remove_column :orders, :rush
    remove_column :orders, :ship_method
    remove_column :orders, :fob
    remove_column :orders, :closed
    
    remove_column :order_items, :ship_date
    remove_column :order_items, :ship_tracking
    
    drop_table :artwork_order_tags
  end
end
