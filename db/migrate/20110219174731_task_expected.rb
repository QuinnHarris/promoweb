class TaskExpected < ActiveRecord::Migration
  def self.up
    %w(customer order order_item).each do |type|
      add_column "#{type}_tasks", :expected_at, :datetime
      change_column "#{type}_tasks", :active, :boolean, :default => nil
    end
  end

  def self.down
    %w(customer order order_item).each do |type|
      change_column "#{type}_tasks", :active, :boolean, :default => true
      remove_column "#{type}_tasks", :expected_at
    end
  end
end
