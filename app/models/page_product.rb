class PageProduct < ActiveRecord::Base
  establish_connection("crawl")
  
  belongs_to :page
  belongs_to :product
end
