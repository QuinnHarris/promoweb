require File.dirname(__FILE__) + '/../config/environment'

customers = Customer.joins(:orders => [:tasks_active, :items]).where("company_name <> ''").where("orders.created_at > '2013-01-01'").where("order_tasks.type = 'CompleteOrderTask'").uniq

exclude = ['Harris Water', 'personal', 'Harper', 'ClueCon', 'Fleishman']

customers.delete_if { |c| exclude.find { |e| c.company_name.include?(e) } }

puts "Total Customers: #{customers.length}"

addresses = Set.new

customers.each do |c|
  c.email_addresses.each do |a|
    if addresses.include?(a.address.downcase)
      puts " !!!! Duplicate Address: #{a.address} !!!"
      next
    end
    addresses << a.address.downcase

    puts "#{a.address}: #{c.person_name} - #{c.company_name}"
    send = Spam.spam_message(c)
    send.to = "quinn@mountainofpromos.com"
    send.deliver
  end
end

puts "Sent #{addresses.length}"
