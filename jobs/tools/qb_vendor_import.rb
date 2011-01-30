require '../generic_import'

require 'rexml/document'

doc = File.open("QBResponse.xml") { |f| REXML::Document.new(f) }

doc.root.get_elements('//VendorRet').each do |vendor|
  name = vendor.get_elements('Name').first.get_text.to_s
  puts "#{name}"

  next unless vendor.get_elements('IsActive').first.get_text == 'true'
  next if (type = vendor.get_elements('VendorTypeRef/FullName')).empty?
  next unless type.first.get_text == 'Supplies'

  list_id = vendor.get_elements('ListID').first.get_text.to_s

  supplier = Supplier.find_by_quickbooks_id(list_id)
  unless supplier
    supplier = Supplier.new(:name => name, :quickbooks_id => list_id)
    puts "NEW"
  end

    [ [ :quickbooks_sequence, 'EditSequence', false ],
      [ :artwork_email, 'Email', false ],
      [ :phone, 'Phone', true ],
      [ :fax, 'Fax', true ] ].each do |db, xml, num|
      val = vendor.get_elements(xml).first
      val = val.get_text.to_s if val
      if val and num
        val = Integer(val.gsub(/[^0-9]/, ''))
      end
      db_val = supplier.send(db)
      if val and db_val != val
        puts " #{db}: #{val} => #{supplier.send(db)}"
        supplier[db.to_s] = val
      end
      supplier.save!
end


#  Supplier.create(:name => name,
#                  :quickbooks_id => vendor.get_elements('ListID').first.get_text.to_s,
#                  :price_source => PriceSource.create(:name => name))
end 
