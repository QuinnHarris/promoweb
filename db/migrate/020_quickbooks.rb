class Quickbooks < ActiveRecord::Migration
  @@tables = %w(suppliers products customers decoration_techniques)
  @@times = %w(order_items order_entries order_item_decorations order_item_entries)
  @@item_aspects = %w(purchaseorder bill)
  @@item_type = %w(decorations entries)
  
  def self.up
    @@tables.each do |table|
      add_column table, :quickbooks_id, :string, :size => 32, :references => nil
      add_column table, :quickbooks_at, :datetime
      add_column table, :quickbooks_sequence, :string, :size => 16
    end

    # update order_entries
    change_column :order_entries, :price, :integer, :default => 0, :null => false
    add_column :order_entries, :quantity, :integer, :default => 1, :null => false
    add_column :order_entries, :quickbooks_id, :string, :size => 32, :references => nil
    add_column :order_entries, :quickbooks_at, :datetime    
    change_column_default :order_entries, :description, ''
    change_column_default :order_entries, :price, 0
    change_column_default :order_entries, :cost, 0

    @@times.each do |table|
      add_column table, :created_at, :datetime
      add_column table, :updated_at, :datetime
      execute("update #{table} set created_at=NOW(), updated_at=NOW()")
      change_column table, :created_at, :datetime, :null => false
      change_column table, :updated_at, :datetime, :null => false
    end
    
    @@item_aspects.each do |aspect|
      add_column 'order_items', "quickbooks_#{aspect}_id", :string, :size => 32, :references => nil
      add_column 'order_items', "quickbooks_#{aspect}_at", :datetime

      @@item_type.each do |type|
        add_column "order_item_#{type}", "quickbooks_#{aspect}_marginal_id", :string, :size => 32, :references => nil
        add_column "order_item_#{type}", "quickbooks_#{aspect}_fixed_id", :string, :size => 32, :references => nil
        add_column "order_item_#{type}", "quickbooks_#{aspect}_at", :datetime
      end
    end

    create_table :purchase_orders do |t|
      t.column :tenative, :boolean, :default => false, :null => false
      t.column :sent, :boolean, :default => false, :null => false
      
      t.column :quickbooks_ref, :string, :size => 16
      
      t.column :quickbooks_id, :string, :size => 32, :references => nil
      t.column :quickbooks_at, :datetime
      t.column :quickbooks_sequence, :string, :size => 16

      t.column :created_at,   :datetime, :null => false
      t.column :updated_at,   :datetime, :null => false  
    end
    
    create_table :purchase_order_entries do |t|
      t.column :purchase_order_id, :integer, :null => false
      t.column :description,   :text, :default => '', :null => false
      
      t.column :price, :integer, :default => 0, :null => false
      t.column :cost, :integer, :default => 0, :null => false
      t.column :quantity, :integer, :default => 1, :null => false
      
      t.column :quickbooks_id, :string, :size => 32, :references => nil
      t.column :quickbooks_at, :datetime      
      
      t.column :created_at,   :datetime, :null => false
      t.column :updated_at,   :datetime, :null => false 
    end
    
    add_column 'order_items', :purchase_order_id, :integer
    
    create_table :quickbooks_deletes do |t|
      t.column :txn_class, :string, :size => 32
      t.column :txn_type, :string, :size => 32
      t.column :txn_id, :string, :size => 32, :references => nil
    end
    
    create_table :invoices do |t|
      t.column :order_id, :integer, :null => false
      
      t.column :comment, :text
      
      t.column :quickbooks_ref, :string, :size => 16

      t.column :quickbooks_id, :string, :size => 32, :references => nil
      t.column :quickbooks_at, :datetime
      t.column :quickbooks_sequence, :string, :size => 16   
      
      t.column :created_at,   :datetime, :null => false
      t.column :updated_at,   :datetime, :null => false 
    end
  
    create_table :invoice_entries do |t|
      t.column :invoice_id, :integer, :null => false
      
      t.column :type, :string, :null => false
      t.column :entry_id, :integer, :references => nil
      
      t.column :description,   :text, :default => '', :null => false
      t.column :data, :text
      
      t.column :total_price, :integer, :default => 0, :null => false
      t.column :quantity, :integer, :default => 1, :null => false
      
      t.column :quickbooks_id, :string, :size => 32, :references => nil
      t.column :quickbooks_at, :datetime      
      
      t.column :created_at,   :datetime, :null => false
      t.column :updated_at,   :datetime, :null => false 
    end
  end

  def self.down
    @@tables.each do |table|
      remove_column table, :quickbooks_id
      remove_column table, :quickbooks_at
      remove_column table, :quickbooks_sequence
    end
    
    remove_column :order_entries, :quantity
    remove_column :order_entries, :quickbooks_id
    remove_column :order_entries, :quickbooks_at
    
    @@times.each do |table|
      remove_column table, :created_at
      remove_column table, :updated_at
    end
    
    @@item_aspects.each do |aspect|
      remove_column 'order_items', "quickbooks_#{aspect}_id"
      remove_column 'order_items', "quickbooks_#{aspect}_at"
      
      @@item_type.each do |type|
        remove_column "order_item_#{type}", "quickbooks_#{aspect}_marginal_id"
        remove_column "order_item_#{type}", "quickbooks_#{aspect}_fixed_id"
        remove_column "order_item_#{type}", "quickbooks_#{aspect}_at"
      end
    end
    
    remove_column 'order_items', :purchase_order_id
    
    drop_table :purchase_order_entries
    drop_table :purchase_orders
    drop table :quickbooks_deletes
    
    drop_table :invoice_entries
    drop_table :invoices
  end
end
