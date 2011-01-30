class UsersName < ActiveRecord::Migration
  def self.up
    # Associate customers and orders with users (employee)
    add_column :customers, :user_id, :integer
    add_column :orders, :user_id, :integer
    
    add_column :users, :name, :string
    add_column :users, :email, :string
  end

  def self.down
  end
end
