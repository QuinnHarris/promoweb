class Payments < ActiveRecord::Migration
  def self.up
    create_table :payment_methods do |t|
      t.column :customer_id, :integer, :null => false
      t.column :address_id, :integer, :null => false
      t.column :type, :string, :null => false
      t.column :name, :string, :null => false
      t.column :display_number, :string, :null => false
      t.column :billing_id, :string, :null => false, :references => nil

      t.column :created_at,   :datetime, :null => false
      t.column :updated_at,   :datetime, :null => false  
    end
    
    create_table :payment_transactions do |t|
      t.column :method_id, :integer, :null => false, :references => :payment_methods
      t.column :order_id, :integer, :null => false
      t.column :type, :string, :null => false
      t.column :amount, :integer, :null => false
      t.column :comment, :text
      
      t.column :created_at,   :datetime, :null => false
    end
  end

  def self.down
    drop_table :payment_methods
    drop_table :payment_transactions
  end
end
