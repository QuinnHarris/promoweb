class QuickbooksCleanup < ActiveRecord::Migration
  @@tables = %w(purchase_order_entries invoice_entries)
  @@item_aspects = %w(purchaseorder bill)
  @@item_type = %w(decorations entries)

  def self.up
    @@tables.each do |table|
      remove_column table, :quickbooks_at
      remove_column table, :quickbooks_id
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
  end

  def self.down
    @tables.each do |table|
      add_column table, :quickbooks_at, :datetime
      add_column table, :quickbooks_id, :string, :size => 32, :references => nil
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
  end
end
