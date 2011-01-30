# Load Rails
require File.dirname(__FILE__) + '/../../config/environment'


PageProduct.find(:all,
                 :conditions => "NOT NULLVALUE(correct)",
                 :include => [:page => :site],
                 :order => "correct DESC, product_id").each do |pp|
  puts "#{pp.correct}, #{pp.product_id}, #{pp.page.site.class}, #{pp.page.request_uri}"
end
