class ShippingRate < ActiveRecord::Base
  belongs_to :customer
  belongs_to :product
  def supplier; product.supplier; end

  serialize :data, Array
  # data is list of [code, description, days, price]

  def self.get(qty, prod, cust, fetch = false)
    sr = find(:first, :conditions => {
           :product_id => prod.id,
           :customer_id => cust.id,
           :quantity => qty })
    if fetch and !sr
      sr = new(:product => prod,
               :customer => cust,
               :quantity => qty)
      #return nil unless sr.set_rates
      sr.save!
    end
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
  serialize :data, Array

  def set_rates
    unless (package_units = product.package_units) and (package_units > 0)
      logger.error("No Package Units")
      return nil
    end

    package_count = (quantity.to_f / package_units).ceil
    if package_count > 50
      logger.error("More than 50 packages: #{package_count}")
      return nil
    end

    package_full_count = (quantity.to_f / package_units).floor
    package_tail_units = quantity - (package_units*package_full_count)

    unless product.package_weight || product.package_unit_weight
      logger.error("No Package Weight")
      return nil 
    end
    if product.package_weight
      package_weight = product.package_weight
      units_weight = package_weight / package_units
    else
      units_weight = product.package_unit_weight
      package_weight = units_weight * package_units
    end
    
    unless supplier.address
      logger.error("No supplier address")
      return nil 
    end

    unless ship_address = customer.ship_address || customer.default_address
      logger.error("No customer address")
      return nil 
    end
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
      logger.error("Shipping fail")
      return nil
    end

    data = shipments.collect do |shipment|
      unless days = shipment.days
        tit = tits.find { |t| t.shipping_code == shipment.service_code }
        days = tit.days if tit and tit.guaranteed
      end
      [shipment.service_code, shipment.total_price.to_f, days, shipment.time]
    end.sort_by { |c, p, d, t| p }
    write_attribute(:data, data)
  end

  def rates
    data && data.collect { |s| UPSService.new(s) }
  end
end

class ShippingRate
  def self.rates(qty, prod, cust, fetch = false)
    rates = [UPSShippingRate].collect do |klass|
      sr = klass.get(qty, prod, cust, fetch)
      sr.rates || false if sr
    end.flatten.compact
    return nil if rates.empty?
    rates + [ShipService.new]
  end
end
