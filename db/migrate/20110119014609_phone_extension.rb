class PhoneExtension < ActiveRecord::Migration
  def self.up
    add_column :users, :extension, :integer
    add_column :users, :phone, :integer
  end

  def self.down
  end
end
