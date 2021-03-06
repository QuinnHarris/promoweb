xml.instruct! :xml, :version=> '1.0', :encoding => 'UTF-8'
xml.directory do
  xml.item_list do
    for user in @users
      xml.item do
        xml.fn user.name
	xml.ct user.login
	xml.sd user.extension
	xml.rt 12
	xml.bw 1
      end
    end

    for supplier in @suppliers
      xml.item do
        xml.fn supplier.name
	xml.ct supplier.phone
	xml.rt 11
      end
    end
  end
end