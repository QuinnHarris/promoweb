class Calls < ActiveRecord::Migration
  def self.up
    create_table :call_logs do |t|
      t.string :uuid, :limit => 36

      t.string :caller_number
      t.string :caller_name
      t.string :called_number
      t.boolean :inbound, :null => false, :default => false
      t.references :customer

      t.datetime :create_time, :null => false
      t.datetime :ring_time
      t.datetime :answered_time
      t.references :user

      t.string :chan_name

      t.string :end_reason
      t.datetime :end_time
    end
    add_foreign_key(:call_logs, :customers)
    add_foreign_key(:call_logs, :users)

#    remove_column :users, :incoming_phone_number
#    remove_column :users, :incoming_phone_name
#    remove_column :users, :incoming_phone_time
  end

  def self.down
  end
end
