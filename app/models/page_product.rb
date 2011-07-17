class PageProduct < ActiveRecord::Base 
  belongs_to :page
  belongs_to :product
end
