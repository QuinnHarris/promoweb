class Leadtime < ActiveRecord::Migration
  def self.up
    add_column :products, :lead_time_normal_min, :integer
    add_column :products, :lead_time_normal_max, :integer
    add_column :products, :lead_time_rush, :integer
    add_column :products, :lead_time_rush_charge, :float

    Product.update_all('lead_time_normal_min = 5, lead_time_normal_max = 7, lead_time_rush = 1', 'supplier_id = 2')
    Product.update_all('lead_time_normal_min = 3, lead_time_normal_max = 5, lead_time_rush = 1', 'supplier_id = 3')
  end

  def self.down
    remove_column :products, :lead_time_normal_min
    remove_column :products, :lead_time_normal_max
    remove_column :products, :lead_time_rush
    remove_column :products, :lead_time_rush_charge
  end
end
