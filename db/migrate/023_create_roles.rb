class CreateRoles < ActiveRecord::Migration
  def self.up
    remove_column :users, :super
    add_column :users, :email, :string
    
    create_table :permissions do |t|
      t.string :name
      t.integer :user_id, :null => false
      t.integer :order_id
      t.timestamps
    end
    execute "ALTER TABLE permissions ADD CONSTRAINT permissions_uniq UNIQUE(name, user_id, order_id)"
    
    create_table :delegatables do |t|
      t.string :name
      t.integer :user_id, :null => false
    end
    execute "ALTER TABLE delegatables ADD CONSTRAINT delegatables_uniq UNIQUE(name, user_id)"
  end

  def self.down
    drop_table :permissions
    drop_table :delegatables
  end
end
