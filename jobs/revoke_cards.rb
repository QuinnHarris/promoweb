require File.dirname(__FILE__) + '/../config/environment'

pms = PaymentMethod.find(:all,
  :conditions => "NOT NULLVALUE(billing_id) AND " +
  "customer_id NOT IN (SELECT customer_id FROM orders WHERE closed = false)")
puts "Reviking #{pms.length}"
pms.each do |pm|
  pm.revoke!
end
