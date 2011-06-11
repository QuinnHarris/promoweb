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
      t.integer :external_phone_timeout, :null => false, :default => 15
      t.string :phone_password
    end
    User.update_all("extension = extension + 90", '')

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
      t.string :address
      t.string :notes
    end
    add_foreign_key(:email_addresses, :customers)
    add_index(:email_addresses, :address)

    Customer.find(:all).each do |customer|
      unless customer.phone.blank?
        PhoneNumber.create(:customer => customer,
                           :number_string => customer.phone)
      end

      unless customer.email.blank?
        customer.email.split(',').each do |email|
          EmailAddress.create(:customer => customer,
                              :address => email.strip)
        end
      end
    end
    remove_column :customers, :phone
    remove_column :customers, :email
  end

  def self.down
    drop_table :phones
  end
end
