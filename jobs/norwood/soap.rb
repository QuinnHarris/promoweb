#require 'rubygems'
#gem 'soap4r'
require "soap/wsdlDriver"
require 'rexml/document'

wsdl_file = "OrderStatus.wsdl"
factory = SOAP::WSDLDriverFactory.new(wsdl_file)
@driver = factory.create_rpc_driver
#esponse = @driver.getOrdersAsXML('573654')
response = @driver.getOrdersAsXML('585291')

@doc = REXML::Document.new(response)

fields = %w(po line_number product_number product_description quantity_ordered quantity_shipped unit_price scheduled_ship_date order_status freight_charges tracking_number ship_date destination_zip account_number location_id)
@doc.root.each_element do |order| 
  fields.each do |name|
    value = order.get_elements(name).first.get_text
    puts "#{name.split('_').collect { |n| n.capitalize }.join(' ')}: #{value}"
  end
  puts
end
