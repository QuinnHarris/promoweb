class CategoryProduct < ActiveRecord::Base
  set_table_name 'categories_products'
  belongs_to :category
  belongs_to :product
end
