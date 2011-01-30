xml.AastraIPPhoneFormattedTextScreen(:destroyOnExit => 'yes') do
  @lines.each do |line|
    xml.Line line
  end

  xml.SoftKey(:index => 1) do
    xml.Label 'Answer'
    xml.URI 'SoftKey:Answer'
  end

  xml.SoftKey(:index => 2) do
    xml.Label 'Ignore'
    xml.URI 'SoftKey:Ignore'
  end

  xml.SoftKey(:index => 6) do
    xml.Label 'Done'
    xml.URI 'SoftKey:Exit'
  end
end
