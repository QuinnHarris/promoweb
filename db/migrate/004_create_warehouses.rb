class CreateWarehouses < ActiveRecord::Migration
  def self.up
    create_table :warehouses do |t|
      t.column :supplier_id, :integer
      
      t.column :address_1,     :string
      t.column :address_2,     :string
      t.column :city,          :string
      t.column :state,         :string
      t.column :postalcode,    :string
    end
  end

  def self.down
    drop_table :warehouses
  end
end
