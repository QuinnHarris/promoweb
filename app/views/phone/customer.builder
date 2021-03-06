xml.AastraIPPhoneFormattedTextScreen(:destroyOnExit => 'yes') do
  xml.Line "----- Customer -----"
  xml.Line @customer.company_name
  xml.Line @customer.person_name
  xml.Line @customer.phone_numbers.first.number_string
  orders = @customer.orders.find(:all, :conditions => 'NOT closed').collect { |o| o.id }
  unless orders.empty?  
    xml.Line 'Orders: ' + orders.join(',')
  end

  xml.SoftKey(:index => 1) do
    xml.Label 'Dial'
    xml.URI "Dial:#{@customer.phone_numbers.first.number}"
  end

  if @list
    @list = @list[0...4] if @list.length > 4
    index = (4 - @list.length) / 2 + 1
    @list.each do |label, number|
      xml.SoftKey(:index => (index += 1)) do
        xml.Label label
        xml.URI "Dial:#{number}"
      end      
    end
  end

  xml.SoftKey(:index => 6) do
    xml.Label 'Done'
    xml.URI 'SoftKey:Exit'
  end
end
