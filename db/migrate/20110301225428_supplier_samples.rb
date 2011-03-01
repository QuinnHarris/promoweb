class SupplierSamples < ActiveRecord::Migration
  def self.up
    add_column :suppliers, :samples_email, :string
    add_column :orders, :delivery_date_not_important, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :suppliers, :samples_email
  end
end
