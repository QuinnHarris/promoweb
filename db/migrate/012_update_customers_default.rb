class UpdateCustomersDefault < ActiveRecord::Migration
  def self.up   
    %w(marginal fixed).each do |pre|
      %w(price cost).each do |post|
        change_column_default :order_item_entries, "#{pre}_#{post}", 0
      end
    end
    change_column_default :order_item_entries, :description, ''
    
    [:marginal_price, :fixed_price].each do |col|
      change_column(:order_items, col, :integer, :null => true)
    end
  end

  def self.down
  end
end
