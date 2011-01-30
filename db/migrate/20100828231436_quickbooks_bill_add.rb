class QuickbooksBillAdd < ActiveRecord::Migration
  def self.up
    %w(order_item_variants order_items).each do |name|
      add_column name, :quickbooks_bill_id, :string, :size => 32, :references => nil
    end
    rename_column :order_items, :quickbooks_po_shiping_id, :quickbooks_po_shipping_id
    add_column :order_items, :quickbooks_bill_shipping_id, :string, :size => 32, :references => nil

    %w(order_item_decorations order_item_entries).each do |name|
      add_column name, :quickbooks_bill_marginal_id, :string, :size => 32, :references => nil
      add_column name, :quickbooks_bill_fixed_id, :string, :size => 32, :references => nil
    end

    add_column :purchase_entries, :quickbooks_po_id, :string, :size => 32, :references => nil
    add_column :purchase_entries, :quickbooks_bill_id, :string, :size => 32, :references => nil
  end

  def self.down
  end
end
