class CreatePhones < ActiveRecord::Migration
  def self.up
    create_table :phones do |t|
      t.integer :user_id, :null => false
      t.string :name, :null => false
      t.string :identifier
      t.timestamps
    end
    add_foreign_key(:phones, :users)

    change_table :users do |t|
      t.remove :phone
      t.integer :direct_phone_number, :limit => 8
      t.integer :external_phone_number, :limit => 8
      t.boolean :external_phone_enable, :null => false, :default => false
      t.boolean :external_phone_all, :null => false, :default => false
      t.integer :external_phone_timeout
      t.string :phone_password
    end
    User.update_all("extension = extension + 100", '')

    create_table :calls do |t|
      t.string :uuid, :limit => 36

      t.string :caller_number
      t.string :called_number
      t.boolean :inbound
      t.references :customer

      t.datetime :create_time, :null => false
      t.datetime :ring_time
      t.datetime :answered_time
      t.references :user

      t.string :end_reason, :null => false
      t.datetime :end_time, :null => false
    end
    add_foreign_key(:calls, :customers)
    add_foreign_key(:calls, :users)

    create_table :phone_numbers do |t|
      t.integer :customer_id
      t.string :name
      t.integer :number, :limit => 8
      t.string :number_string
      t.string :notes
    end
    add_foreign_key(:phone_numbers, :customers)
    add_index(:phone_numbers, :number)

    create_table :email_addresses do |t|
      t.integer :customer_id
      t.string :name
      t.string :address
      t.string :notes
    end
    add_foreign_key(:email_addresses, :customers)
    add_index(:email_addresses, :address)
  end

  def self.down
    drop_table :phones
  end
end
