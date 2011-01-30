class Superuser < ActiveRecord::Migration
  def self.up
    add_column :users, :super, :boolean, :null => false, :default => false
    User.update_all('super = true')
    remove_column :users, :email
  end

  def self.down
    remove_column :users, :super
    add_column :users, :email, :string
  end
end
