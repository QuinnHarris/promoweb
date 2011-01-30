class CreateCustomers < ActiveRecord::Migration
  def self.up
    create_table :addresses do |t|
      t.column :name,          :string
      t.column :address_1,     :string
      t.column :address_2,     :string
      t.column :city,          :string
      t.column :state,         :string
      t.column :postalcode,    :string    
    end
  
    create_table :customers do |t|
      # t.column :name, :string
      t.column :uuid,          :string, :length => 22, :null => false
      t.column :username,      :string
      t.column :password,      :string
      
      t.column :company_name,  :string
      t.column :person_name,   :string

      t.column :default_address_id, :integer, :references => :addresses
      t.column :ship_address_id, :integer, :references => :addresses
      t.column :bill_address_id, :integer, :references => :addresses

      t.column :phone,         :string, :length => 14
      t.column :email,         :string
      
      t.column :created_at,   :datetime, :null => false
      t.column :updated_at,   :datetime, :null => false
    end
    execute "ALTER TABLE customers ADD CONSTRAINT unique_uuid UNIQUE(uuid)"
    execute "ALTER TABLE customers ADD CONSTRAINT unique_username UNIQUE(username)"
    
    create_table :order_states do |t|
      t.column :name, :string, :null => false
    end
    execute "ALTER TABLE order_states ADD CONSTRAINT unique_name UNIQUE(name)"
    OrderState.create({:name => 'quote_auto'})
    OrderState.create({:name => 'quote_submit'})
    
    create_table :orders do |t|
      t.column :customer_id,   :integer, :null => false
      t.column :delivery_date, :date
      t.column :event_nature,  :string
      t.column :special,       :string
      t.column :customer_notes,:text
      t.column :our_notes,     :text
      
      t.column :order_state_id, :integer, :null => false
      
      t.column :created_at,   :datetime, :null => false
      t.column :updated_at,   :datetime, :null => false
    end
    
    create_table :order_entries do |t|
      t.column :order_id,      :integer, :null => false
      t.column :name,          :string
      t.column :description,   :text
      
      t.column :price, :integer
    end
    
    create_table :order_items do |t|
      t.column :order_id,      :integer, :null => false
      t.column :price_group_id, :integer, :null => false
      t.column :variant_id,    :integer
      t.column :quantity,      :integer, :null => false
      
      t.column :customer_notes,:text
      t.column :our_notes,     :text
      
      t.column :marginal_price, :integer
      t.column :fixed_price, :integer
    end
    
    create_table :order_item_entries do |t|
      t.column :order_item_id, :integer, :null => false
      t.column :name,          :string
      t.column :description,   :text
      
      t.column :marginal_price, :integer
      t.column :fixed_price, :integer
    end
    
    create_table :order_item_decorations do |t|
      t.column :order_item_id, :integer, :null => false
      t.column :technique_id,  :integer, :references => :decoration_techniques, :null => false
#      t.column :location, :text
      t.column :decoration_id, :integer
      t.column :count, :integer
      t.column :image, :text
      
      t.column :marginal_price, :integer
      t.column :fixed_price, :integer    
    end
    execute "ALTER TABLE order_item_decorations ADD CONSTRAINT unique_order_item_decorations UNIQUE(order_item_id, technique_id, decoration_id)"
  end

  def self.down
    drop_table :customers
  end
end

#CreateCustomers.establish_connection(RAILS_ENV + '_orders')
