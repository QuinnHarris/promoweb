class PoBillSplit < ActiveRecord::Migration
  def self.up
    rename_table :purchase_orders, :purchases
    rename_column :order_items, :purchase_order_id, :purchase_id

    rename_table :purchase_order_entries, :purchase_entries
    rename_column :purchase_entries, :purchase_order_id, :purchase_id

    %w(purchase_orders bills).each do |name|
      create_table name do |t|
        t.column :purchase_id, :integer, :null => false

        if name == 'purchase_orders'
          t.column :sent, :boolean, :default => false, :null => false
        end

        t.column :quickbooks_ref, :string, :size => 16
        t.column :quickbooks_id, :string, :size => 32, :references => nil
        t.column :quickbooks_at, :datetime
        t.column :quickbooks_sequence, :string, :size => 16
        
        t.timestamps
      end
    end

    %w(order_item_variants order_items).each do |name|
      add_column name, :quickbooks_po_id, :string, :size => 32, :references => nil
    end
    add_column :order_items, :quickbooks_po_shiping_id, :string, :size => 32, :references => nil

    %w(order_item_decorations order_item_entries).each do |name|
      add_column name, :quickbooks_po_marginal_id, :string, :size => 32, :references => nil
      add_column name, :quickbooks_po_fixed_id, :string, :size => 32, :references => nil
    end

    InvoiceEntry.update_all("type = 'InvoicePurchaseEntry'", "type = 'InvoicePurchaseOrderEntry'")

    Purchase.find(:all, :order => 'id', :conditions =>
                  '(quickbooks_id IS NOT NULL) OR (quickbooks_at IS NOT NULL) OR (quickbooks_ref IS NOT NULL) OR (quickbooks_sequence IS NOT NULL)').each do |purchase|
      PurchaseOrder.create({ :purchase => purchase,
                             :sent => purchase[:sent],
                             :quickbooks_ref => purchase[:quickbooks_ref],
                             :quickbooks_id => purchase[:quickbooks_id],
                             :quickbooks_at => purchase[:quickbooks_at],
                             :quickbooks_sequence => purchase[:quickbooks_sequence],
                             :updated_at => purchase[:updated_at],
                             :created_at => purchase[:created_at]})
    end

    remove_column :purchases, :tenative
    remove_column :purchases, :sent
    remove_column :purchases, :quickbooks_ref
    remove_column :purchases, :quickbooks_id
    remove_column :purchases, :quickbooks_at
    remove_column :purchases, :quickbooks_sequence
  end

  def self.down
  end
end
