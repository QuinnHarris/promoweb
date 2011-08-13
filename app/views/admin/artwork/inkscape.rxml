xml.instruct! :xml, :version=> '1.0', :encoding => 'UTF-8'
xml.svg('xmlns:dc' => 'http://purl.org/dc/elements/1.1/',
        'xmlns:cc' => 'http://creativecommons.org/ns#',
	'xmlns:rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
   	'xmlns:svg' => 'http://www.w3.org/2000/svg',
	'xmlns' => 'http://www.w3.org/2000/svg',
	'xmlns:sodipodi' => 'http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd',
	'xmlns:inkscape' => 'http://www.inkscape.org/namespaces/inkscape',
	'width' => "#{((@oid.width || @oid.diameter) * 72).to_i}pt",
	'height' => "#{((@oid.height || @oid.diameter) * 72).to_i}pt",
	'id' => 'svg2',
	'version' => '1.1') do
  xml.tag!('sodipodi:namedview',
	   'inkscape:document-units' => 'in',
	   'units' => 'in')
  xml.metadata do
    xml.tag!('rdf:RDF') do
      xml.tag!('cc:Work') do
        xml.tag!('dc:title', "Order #{@order.id} - " + (@order.customer.company_name.blank? ? @order.customer.person_name : "#{@order.customer.company_name} - #{@order.customer.person_name}"))
	xml.tag!('dc:creator') do
	  xml.tag!('cc:Agent') do
	    xml.tag!('dc:title', "#{@user.name} - Mountain Xpress Promotions, LLC")
	  end
	end
	xml.tag!('dc:identifier', @oid.id.to_s)
	xml.tag!('dc:source', @order.customer.uuid)
      end
    end
  end

  if @colors
    xml.g do
      total_height = [@oid.width, @oid.height, @oid.diameter].compact.max * 72
      box_height = total_height / @colors.length
      text_shrink = 0.8

      y = ((@oid.height*72) - total_height) / 2.0
      for color in @colors
        xml.text({'x' => "-#{box_height*2.1}pt", 'y' => "#{y+box_height*text_shrink}pt",
                  'style' => "font-size:#{box_height*text_shrink}pt;text-anchor:end;fill:#000000;font-family:Arial"}, color.full_name)

        xml.rect('height' => "#{box_height}pt", 'width' => "#{box_height*2}pt", 'x' => "-#{box_height*2}pt", 'y' => "#{y}pt",
                 'style' => "fill:#{color.hex};")
        y += box_height
      end
    end
  end
end
