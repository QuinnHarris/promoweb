class Page < ActiveRecord::Base
  establish_connection("crawl")
  
  belongs_to :site
  has_many :page_products, :order => 'score DESC'
  
  def url
    "http://#{site.url}/#{request_uri}"
  end
  
  def product_page?
    site.product_page?(request_uri)
  end
end
