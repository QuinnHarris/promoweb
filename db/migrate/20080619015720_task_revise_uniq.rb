class TaskReviseUniq < ActiveRecord::Migration
  def self.up
    %w(customer order order_item).each do |type|
      add_column "#{type}_tasks", :active, :boolean, :default => true
      execute "UPDATE #{type}_tasks SET active = true where revoked = false"
      execute "UPDATE #{type}_tasks SET active = NULL where revoked = true"
      execute "ALTER TABLE #{type}_tasks ADD CONSTRAINT #{type}_tasks_unique UNIQUE (#{type}_id, active, type)"
      remove_column "#{type}_tasks", :revoked
      remove_column "#{type}_tasks", :estimate
    end
  end

  def self.down
    raise IrreversibleMigration
  end
end
