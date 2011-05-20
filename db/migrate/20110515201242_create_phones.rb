class CreatePhones < ActiveRecord::Migration
  def self.up
    create_table :phones do |t|
      t.integer :user_id, :null => false
      t.string :type
      t.string :friendly, :null => false
      t.string :identifier
      t.boolean :direct_only
      t.boolean :enabled, :null => false, :default => true
      t.integer :timeout
      t.string :password
      t.integer :vm_password
      t.timestamps
    end
    add_foreign_key(:phones, :users)
  end

  def self.down
    drop_table :phones
  end
end
