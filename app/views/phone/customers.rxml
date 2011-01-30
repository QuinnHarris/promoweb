xml.AastraIPPhoneTextMenu do
  xml.Title 'Current Customers'

  @customers.each do |customer|
    xml.MenuItem do
      xml.Prompt customer.company_name.strip.empty? ? customer.person_name : customer.company_name
      xml.URI "http://www.mountainofpromos.com/phone/customer/#{customer.id}"
      xml.Dial customer.phone.gsub(/[^0-9]/,'')
    end
  end

  xml.SoftKey(:index => 1) do
    xml.Label 'Dial'
    xml.URI 'SoftKey:Dial2'
  end
  xml.SoftKey(:index => 3) do
    xml.Label 'View'
    xml.URI 'SoftKey:Select'
  end
  xml.SoftKey(:index => 6) do
    xml.Label 'Done'
    xml.URI 'SoftKey:Exit'
  end

#  customer_name = @customer.company_name.strip.empty? ? @customer.person_name : @customer.company_name
#  customer_phone = '9' + @customer.phone.gsub(/[^0-9]/,'')
#  xml.SoftKey(:index => 3) do
#    xml.Label customer_name[0...10].strip
#    xml.URI customer_phone
#  end
#  xml.SoftKey(:index => 6) do
#    xml.Label customer_name[10..20].strip
#    xml.URI customer_phone
#  end

end
