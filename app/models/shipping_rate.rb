class ShippingRate < ActiveRecord::Base
  belongs_to :customer
  belongs_to :product
  def supplier; product && product.supplier; end

  serialize :data
  # data is list of [code, description, days, price]

  def self.carriers
    %w(UPS FedEx DHL Trucking Other)
  end

  def self.get(qty, prod, cust, fetch = false)
    sr = find(:first, :conditions => {
           :product_id => prod.id,
           :customer_id => cust.id,
           :quantity => qty })
    return sr if sr

    sr = new(:product => prod,
             :customer => cust,
             :quantity => qty)
    if msg = sr.invalid?
      sr.data = msg
      return sr
    end

    return nil unless fetch
    sr.set_rates
    sr.save!

    sr
  end
end

class ShipService
  @@markup = 1.20
  attr_reader :code, :description, :days, :cost

  def type; 'NONE'; end
  def id
    "#{type}-#{code}"
  end

  def price
    cost && (cost * @@markup).round_cents
  end

  def description_price
    "#{description} : #{cost && cost.to_perty}"
  end


  def initialize
    @description = 'None or Other'
    @cost = Money.new(0)
  end

end

class UPSService < ShipService
  def initialize(list)
    @code, cost, @days, @time = list
    @cost = Money.new(cost).round_cents
  end

  def type; 'UPS'; end

  def description(exclude_transit = false)
    str = UPS::Shipping::Shipment.code_desc(@code)
    str += " (#{@time})" if @time
    str += " [#{@days} days transit]" if !exclude_transit and @days and (UPS::Shipping::Shipment.code_days(@code) != @days)
    str
  end
end

class UPSShippingRate < ShippingRate
  def invalid?
    return "No supplier address" unless supplier.address
    return "Invalid supplier zipcode: #{supplier.address.postalcode}" unless supplier.address.postalcode && supplier.address.postalcode.length == 5

    return "No customer address" unless ship_address = customer.ship_address || customer.default_address
    return "Invalid customer zipcode: #{ship_address.postalcode.length}" unless ship_address.postalcode && ship_address.postalcode.length >= 5 && ship_address.postalcode.split('-').first.length == 5

    return "No Package Units" unless (package_units = product.package_units) and (package_units > 0)
    
    package_count = (quantity.to_f / package_units).ceil
    if package_count > 50
      return "More than 50 packages: #{package_count}"
    end

    unless product.package_weight || product.package_unit_weight
      return "No Package Weight"
    end

    nil
  end

  def set_rates
    data = get_rates
    write_attribute(:data, data)
    data
  end

  def get_rates
    c = invalid?
    return c if c

    package_units = product.package_units
    package_full_count = (quantity.to_f / package_units).floor
    package_tail_units = quantity - (package_units*package_full_count)

    if product.package_weight
      package_weight = product.package_weight
      units_weight = package_weight / package_units
    else
      units_weight = product.package_unit_weight
      package_weight = units_weight * package_units
    end
    

    ship_address = customer.ship_address || customer.default_address
    shipment = UPS::Shipping::Shipment.new
    shipment.shipper_addr = supplier.address.UPSAddress
    shipment.from_addr = shipment.shipper_addr
    shipment.to_addr = ship_address.UPSAddress
    
    dim = UPS::Shipping::Dimension.new
    dim = nil unless %w(length width height).find_all do |f|
      dim.send("#{f}=", product.send("package_#{f}")).blank?
    end.empty?
    
    if package_full_count > 0
      package = UPS::Shipping::Package.new
      package.weight = package_weight
      package.dimension = dim if dim
      package_full_count.times { shipment.packages << package }
    end

    if package_tail_units > 0
      package = UPS::Shipping::Package.new
      package.weight = units_weight * package_tail_units
      package.dimension = dim if dim
      shipment.packages << package
    end

    ratereq = UPS::Shipping::RateRequest.new(shipment)

    titreq = UPS::Transit::TimeInTransitRequest.new
    titreq.from = shipment.shipper_addr
    titreq.to   = shipment.to_addr
    titreq.pickup = Time.now + 2.days
    titreq.weight = shipment.packages.collect { |p| p.weight.value }.max
    titreq.packages = shipment.packages.length

    begin
      ups = UPS::Base.new('4BF2D1D4C2E28409', 'QuinnHarris', 'Hitachi')
      shipments, tits = ups.queries([ratereq, titreq])
    rescue
      return "Shipping fail"
    end

    data = shipments.collect do |shipment|
      unless days = shipment.days
        tit = tits.find { |t| t.shipping_code == shipment.service_code }
        days = tit.days if tit and tit.guaranteed
      end
      [shipment.service_code, shipment.total_price.to_f, days, shipment.time]
    end.sort_by { |c, p, d, t| p }

    return data
  end

  def rates
    return data if data.is_a?(String)
    data && data.collect { |s| UPSService.new(s) }
  end
end

class ShippingRate
  def self.rates(qty, prod, cust, fetch = false)
    rates = [UPSShippingRate].collect do |klass|
      sr = klass.get(qty, prod, cust, fetch)
      sr.rates if sr
    end.flatten.compact
    return nil if rates.empty?
    return rates.first if rates.length == 1 and rates.first.is_a?(String)
    rates + [ShipService.new]
  end
end
