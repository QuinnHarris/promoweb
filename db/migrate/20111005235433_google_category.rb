class GoogleCategory < ActiveRecord::Migration
  def self.up
    add_column :categories, :google_category, :string, :size => 192
  end

  def self.down
    remove_column :categories, :google_category
  end
end
