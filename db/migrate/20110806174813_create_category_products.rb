class CreateCategoryProducts < ActiveRecord::Migration
  def self.up
    add_column :categories_products, :id, :serial
  end

  def self.down
    remove_column :categories_products, :id
  end
end
