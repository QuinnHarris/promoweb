class SupplierAccount < ActiveRecord::Migration
  def self.up
    add_column :suppliers, :account_number, :string
  end

  def self.down
  end
end
