class CreateTask < ActiveRecord::Migration
  def self.up
    create_table :task_definitions do |t|
      t.column :alias, :string, :null =>false
      t.column :name, :string, :null =>false
      t.column :value, :string
      t.column :comments, :text
    end
    execute "ALTER TABLE task_definitions ADD CONSTRAINT unique_task_definitions UNIQUE(alias)"
    TaskDefinition.update_database

    %w(customer order order_item).each do |type|
      create_table "#{type}_tasks" do |t|
        t.column "#{type}_id", :integer, :null => false
        t.column :task_definition_id, :integer, :null => false
      
        t.column :comment,       :text
        t.column :revoked,       :boolean, :default => false, :null => false
      
        t.column :created_at,   :datetime, :null => false
        t.column :updated_at,   :datetime, :null => false  
      end
    end
    
    remove_column :orders, :order_state_id
    drop_table :order_states
  end

  def self.down
    drop_table :task_definitions
    drop_table :customer_tasks
    drop_table :order_tasks
    drop_table :order_item_tasks
  end
end
