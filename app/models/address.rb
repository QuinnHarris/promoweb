class Address < ActiveRecord::Base
#  validates_presence_of :postalcode

  def UPSAddress
    address = UPS::Shipping::Address.new
    address.city = city if city
    if state
      region = Region.find_by_name(state)
      address.province = region.abrev if region
    end
    address.postalcode = postalcode
    #address.country = "USA"
    address.lines = [address_1, address_2].compact
    address
  end
end
