class Urgent < ActiveRecord::Migration
  def self.up
    add_column :orders, :urgent_note, :string
  end


  def self.down
    remove_column :orders, :urgent_note
  end
end
