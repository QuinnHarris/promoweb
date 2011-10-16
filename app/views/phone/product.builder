xml.AastraIPPhoneFormattedTextScreen(:destroyOnExit => 'yes') do
  @products[0...5].each do |product|
    xml.Line "#{product.id} #{product.name}"[0...20]
  end
end
