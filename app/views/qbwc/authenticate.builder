xml.instruct!
xml.tag! "env:Envelope", "xmlns:env" => 'http://schemas.xmlsoap.org/soap/envelope/',
                          "xmlns:xsd" => 'http://www.w3.org/2001/XMLSchema',
			  "xmlns:xsi" => 'http://www.w3.org/2001/XMLSchema-instance' do
  xml.tag! "env:Body" do
    xml.tag!('n1:authenticateResponse', { 'env:encodingStyle' => 'http://schemas.xmlsoap.org/soap/encoding/',
    					  'xmlns:n1' => 'urn:ActionWebService' }) do
      xml.tag!('return', { 'xmlns:n2' => 'http://schemas.xmlsoap.org/soap/encoding/',
			   'n2:arrayType' => 'xsd:string[2]', 'xsi:type' => 'n2:Array' }) do
        xml.item ticket
	xml.item status
      end
    end
  end
end
