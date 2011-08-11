require File.dirname(__FILE__) + '/../config/environment'

pms = PaymentMethod.find(:all,
  :conditions => "billing_id IS NOT NULL AND " +
  "customer_id NOT IN (SELECT customer_id FROM orders WHERE closed = false OR updated_at > NOW() - '2 weeks'::interval)")
puts "Reviking #{pms.length}"
pms.each do |pm|
  pm.revoke!
end
