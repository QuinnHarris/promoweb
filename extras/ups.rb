require 'rubygems'
#require 'money'
require 'rexml/document'
require 'builder'
require 'net/http'
require 'net/https'

require 'benchmark'

class Class
  def attr_create(type, *syms)
    syms.flatten.each do |sym|
      define_method(sym) do
        eval <<-EOS
          return @#{sym} if @#{sym}
          @#{sym} = #{type}.new
        EOS
      end
  
      define_method("#{sym}=") do |val|
        eval <<-EOS
          return @#{sym} = #{type}.new(val) unless val.is_a?(type)
          @#{sym} = val
        EOS
      end
    end
  end
end

module UPS
  class Request
    
    def request_string
      
    end
  end

  class UPSMoney
    def initialize(amount = 0.0, currency = 'USD')
      @amount = amount
      @currency = currency
    end
    
    attr_reader :amount, :currency
    def to_f; @amount; end
    def to_s; @amount.to_s; end
    
    def to_UPS(b)
      b.CurrencyCode @currency
      b.MonetaryValue @amount
    end
    
    def from_UPS(node)
      @currency = node.elements['CurrencyCode'].text
      @amount = Float(node.elements['MonetaryValue'].text)
    end
  end

  class TypeNumber
    def initialize(value, unit)
      @value, @unit = value, unit
    end
    attr_accessor :unit, :value
  end
  
  class Weight < TypeNumber
    def initialize(value = nil, unit = 'LBS')
      super value, unit
    end
    
    def to_s
      "#{@value} #{@unit}"
    end
    
    def to_UPS(weight)
      weight.UnitOfMeasurement do |unit|
        # LBS, KGS
        unit.Code(@unit)
        #unit.Description
      end
      weight.Weight(@value)
    end
    
    def from_UPS(node)
      @unit = node.elements['UnitOfMeasurement'].elements['Code'].text
      @value = Float(node.elements['Weight'].text)
    end
  end

  class Address
    attr_accessor :city, :province, :postalcode, :country, :residential

    def initialize
      @country = 'US'
    end

    def to_transit_UPS(b)
      b.AddressArtifactFormat do |a|
        a.PoliticalDivision1(@province) if @province
        a.PoliticalDivision2(@city) if @city
        #          a.PoliticalDivision3() if 
        a.CountryCode(@country)
        a.PostcodePrimaryLow(@postalcode) if @postalcode
        
        a.ResidentialAddressIndicator if @residential
      end
    end
    
    def to_s
      str = ''
      str += "City: #{@city}" if @city
      str += "Province: #{@provice}" if @province
      str += "Postalcode: #{@postalcode}" if @postalcode
      str += "Country: #{country}" if @country
      str
    end
  end

  module Shipping 
    class Dimension
      attr_accessor :length, :width, :height, :unit

      def to_UPS(b)
        b.Dimensions do |dim|
          dim.UnitOfMeasurement do |unit|
            # IN, CM
            unit.Code('IN')
            # unit.Description
          end
          # Rounded
          dim.Length(@length)
          dim.Width(@width)
          dim.Height(@height)
        end    
      end
    end
    
    class Address < ::UPS::Address
      attr_create Array, :lines

      def to_UPS(b)
        b.Address do |address|
          @lines && @lines[0..3].each_with_index do |line, i|
            address.tag!("AddressLine#{i+1}", line)
          end

          address.City(@city) if @city
          address.StateProvinceCode(@province) if @province
          address.PostalCode(@postalcode) if @postalcode
          address.CountryCode(@country) if @country

          address.ResidentialAddressIndicator(1) if @residential
        end      
      end
    end
    
    class Package
      attr_create Dimension, :dimension
      attr_create Weight, :weight
      
      # Return Values
      attr_create UPSMoney, :trans_price, :service_price, :total_price

      def to_UPS(package)
        package.PackagingType do |type|
          # 00 - UNKOWN
          # 01 - UPS Letter
          # 02 - Package
          # 03 - Tube
          # 04 - Pak
          # 21 - Express Box
          # 24 - 25KG Box
          # 25 - 10KG Box
          # 30 - Pallet
          # 2a - Small Express Box
          # 2b - Medium Express Box
          # 2c - Large Express Box
          type.Code('02')
          type.Description('Package')
        end
        @dimension.to_UPS(package) if @dimension

        package.PackageWeight do |weight|
          @weight.to_UPS(weight)
        end

        #package.LargePackageIndicator
        #package.PackageServiceOptions
        # Service Options
      end
      
      def from_UPS(node)
        trans_price.from_UPS(node.elements["TransportationCharges"])
        service_price.from_UPS(node.elements["ServiceOptionsCharges"])
        total_price.from_UPS(node.elements["TotalCharges"])
        
        weight.from_UPS(node.elements["BillingWeight"])
      end
    end

    # incomplete
    class PackageServiceOptions
      attr_create UPSMoney, :value
    end
    
    class Shipment
      attr_create Array, :packages
      attr_create Address, :from_addr, :to_addr, :shipper_addr
      attr_create Weight, :weight
      attr_create UPSMoney, :insured_value
      attr_create String, :shipper_number, :shipper_name, :shipto_name, :shipfrom_name
      attr_accessor :documents
      
      # Return Values
      attr_accessor :service, :service_code
      attr_create UPSMoney, :trans_price, :service_price, :total_price
      
      attr_accessor :days, :time

      @@code_desc = {
        '01' => 'UPS Next Day Air',
        '02' => 'UPS 2nd Day',
        '03' => 'UPS Ground',
        '07' => 'UPS Worldwide Express',
        '08' => 'UPS Worldwide Expedited',
        '11' => 'UPS Standard',
        '12' => 'UPS 3 Day Select',
        '13' => 'UPS Next Day Air Saver',
        '14' => 'UPS Next Day Air Early A.M.',
        '54' => 'UPS Worldwide Express Plus',
        '59' => 'UPS 2nd Day Air A.M.',      
      }
      def self.code_desc_hash; @@code_desc; end
      def self.code_desc(code)
        @@code_desc[code]
      end

      @@code_days = {
        '01' => 1,
        '02' => 2,
        '12' => 3,
        '13' => 1,
        '14' => 1,
        '59' => 2,
      }
      def self.code_days(code)
        @@code_days[code]
      end
      
      def to_UPS(b)
        b.Shipment do |shipment|
          shipment.Shipper do |shipper|
            shipper.Name(@shipper_name) if @shipper_name
            shipper.ShipperNumber(@shipper_number) if @shipper_number
            @shipper_addr.to_UPS(shipper)
          end if @shipper_addr
          
          shipment.ShipTo do |shipto|
            shipto.CompanyName(@shipto_name) if @shipto_name
            @to_addr.to_UPS(shipto)
          end
          
          shipment.ShipFrom do |shipfrom|
            shipto.CompanyName(@shipto_name) if @shipto_name
            @from_addr.to_UPS(shipfrom)
          end if @from_addr
          
          #       shipment.Service do |service|
          #         service.Code('11')
          #         service.Description
          #       end

          shipment.DocumentsOnly(1) if @documents
          
          packages.each do |package|
            shipment.Package do |pkg|
              package.to_UPS(pkg)
            end # package
          end
          
          shipment.PackageServiceOptions do |opts|
            # COD
            # Deliverty Confirmation
            opts.InsuredValue do |ins|
              ins.CurrencyCode(@insured_value.currency)
              ins.MonetaryValue(@insured_value.to_f)
            end if @insured_value
          end
          # ShipmentServiceOptions ...
          # 
        end # shipment      
      end

      def service
        self.class.code_desc(@service_code)
      end
      
      def from_UPS(node)
        @service_code = node.elements['Service'].elements['Code'].text;
        
        weight.from_UPS(node.elements["BillingWeight"])
        
        trans_price.from_UPS(node.elements["TransportationCharges"])
        service_price.from_UPS(node.elements["ServiceOptionsCharges"])
        total_price.from_UPS(node.elements["TotalCharges"])
        
        days = node.elements['GuaranteedDaysToDelivery'].text
        @days = Integer(days) if days
        
        @time = node.elements['ScheduledDeliveryTime'].text
        
        node.elements.each("RatedPackage") do |pkg|
          package = Package.new
          package.from_UPS(pkg)
          packages << package
        end
      end
    end

    class RateRequest < Request
      @@package_type_codes = {
        '01' => 'UPS letter/ UPS Express Envelope',
        '02' => 'Package',
        '03' => 'UPS Tube',
        '04' => 'UPS Pak',
        '21' => 'UPS Express Box',
        '24' => 'UPS 25Kg Box',
        '25' => 'UPS 10Kg Box',
      }

      def initialize(shipment)
        @shipment = shipment
      end

      def path; '/ups.app/xml/Rate'; end

      def generate(b)
        b.RatingServiceSelectionRequest do |rat|
          rat.Request do |req|
            req.TransactionReference do |ref|
              ref.CustomerContext('Rating and Service')
              #ref.XpciVersion('1.0001') "Deprecated"
            end
            req.RequestAction('Rate')
            req.RequestOption('shop') # rate | shop
          end
          
          # Required: "Yes*"
          #          rat.PickupType do |pickup|
          #            # 01 - Daily Pickup
          #            # 03 - Customer Counter
          #            # 06 - One Time Pickup
          #            # 07 - On Call Air
          #            # 11 - Suggested Retail Rates
          #            # 19 - Letter Center
          #            # 20 - Air Service Center
          #            pickup.code('01')
          #          end
          
          rat.CustomerClassification do |clas|
            # 01 - Wholesale
            # 03 - Occasional
            # 04 - Retail
            clas.Code('01')
          end
          
          @shipment.to_UPS(rat)
        end # request
      end

      def parse(result)
        shipments = []
        result.root.elements.each("RatedShipment") do |smt|
          shipment = Shipping::Shipment.new
          shipment.from_UPS(smt)
          shipments << shipment        
        end
        shipments
      end
    end
  end

  module Transit
    class ServiceSummary
      @@code_desc = {
        '1DM' => 'UPS Next Day Air Early A.M.',
        '1DA' => 'UPS Next Day Air',
        '1DP' => 'UPS Next Day Air Saver',
        '2DM' => 'UPS 2nd Day Air A.M.',
        '2DA' => 'UPS 2nd',
        '3DS' => 'UPS 3 Day Select',
        'GND' => 'UPS Ground',
#        '07' => 'UPS Worldwide Express',
#        '08' => 'UPS Worldwide Expedited',
#        '11' => 'UPS Standard',
#        '54' => 'UPS Worldwide Express Plus',
      }
      @@code_to_shipping = {}
      @@code_desc.each do |code, name|
        c, d = ::UPS::Shipping::Shipment.code_desc_hash.find { |c, d| d == name }
        raise "Unkown Description: #{d}" unless d
        @@code_to_shipping[code] = c
      end

      attr_reader :service_code, :guaranteed, :days

      def shipping_code
        @@code_to_shipping[@service_code]
      end
      
      def from_UPS(node)
        @service_code = node.elements['Service'].elements['Code'].text

        @guaranteed = node.elements['Guaranteed'].elements['Code'].text == 'Y'
        ea = node.elements['EstimatedArrival'].elements
        @days = Integer(ea['BusinessTransitDays'].text)
#        @time = Time.parse(ea['Time'].text)      
      end
    end

    class TimeInTransitRequest < Request
      attr_create Address, :from, :to
      attr_create Time, :pickup
      attr_create Weight, :weight
      attr_create Integer, :packages
      attr_create UPSMoney, :value

      def path; '/ups.app/xml/TimeInTransit'; end

      def generate(req)
        req.TimeInTransitRequest do |req|
          req.Request do |req|
            req.TransactionReference do |ref|
              ref.CustomerContext('TNT_D Origin Country Code')
              ref.XpciVersion('1.0002')
            end
            req.RequestAction('TimeInTransit')
          end

          req.TransitFrom do |t|
            @from.to_transit_UPS(t)
          end
          req.TransitTo do |t|
            @to.to_transit_UPS(t)
          end
          req.PickupDate(@pickup.strftime("%Y%m%d"))
#          req.Time(@pickup.strftime("%H%M")) if @pickup.hour != 0 or @pickup.min != 0 or @pickup.sec != 0

          req.ShipmentWeight do |w|
            @weight.to_UPS(w)
          end if @weight

          req.TotalPackagesInShipment(@packages) if @packages

          req.InvoiceLineTotal do |i|
            @value.to_UPS(i)
          end if @value

          #req.DocumentsOnlyIndicator
          #req.MaximumListSize
        end
      end
      
      def parse(result)
        services = []
        result.root.elements['TransitResponse'].elements.each('ServiceSummary') do |srv|
          ss = ServiceSummary.new
          ss.from_UPS(srv)
          services << ss
        end if result.root.elements['TransitResponse']
        services
      end
    end
  end

  class MyHTTP < Net::HTTP
    def initialize(address, port = nil)
      super address, port
    end

    def request_write(req, body = nil)
      start unless started?

      req.set_body_internal body
      begin_transport req
      req.exec @socket, @curr_http_version, edit_path(req.path)
    end

    def request_read(req)
      res = nil
      begin
        res = Net::HTTPResponse.read_new(@socket)
      end while res.kind_of?(Net::HTTPContinue)
      res.reading_body(@socket, req.response_body_permitted?) {
        yield res if block_given?
      }
      end_transport req, res

      res
    end
  end
    
  class Base
    attr_reader :access, :userid, :password

    def initialize(access, userid, password)
      @access, @userid, @password = access, userid, password
    end

    def start(&block)
      @connection = MyHTTP.new 'wwwcie.ups.com', 443
      @connection.use_ssl        = true
      @connection.verify_mode = OpenSSL::SSL::VERIFY_NONE

      @connection.start(&block)
    end

    def started?
      @connection && @connection.started?
    end
    
private
    def generate_authenticate
      return @authenticate_string if @authenticate_string
      @authenticate_string = ''
      b = Builder::XmlMarkup.new :target => @authenticate_string
      b.instruct!
      b.AccessRequest do |b|
        b.AccessLicenseNumber @access
        b.UserId @userid
        b.Password @password
      end
      @authenticate_string
    end

    def request_string(request)
      head = generate_authenticate
      data = ''
      b = Builder::XmlMarkup.new :target => data
      b.instruct!
      request.generate(b)
      head + data
    end
    
    def do_request(request)
      unless started?
        start { 
          return do_request(request)
        }
      end
      
      data = request_string(request)
      
        
      #puts "Request: #{data}"
      #File.open('in.xml', 'w') { |f| f.write(data) }
      
      response_plain = @connection.post(request.path, data).body
      response       = response_plain.include?('<?xml') ? REXML::Document.new(response_plain) : response_plain

      File.open('/home/quinn/out.xml', 'w') { |f| f.write(response_plain) }

      request.parse(response)
    end

    def do_requests(requests)
      unless started?
        start { 
          return do_requests(requests)
        }
      end

      i = 0
      reqs = requests.collect do |request|
        body = request_string(request)
#        File.open("/home/quinn/request#{i += 1}.xml", 'w') { |f| f.write(body) }
        req = Net::HTTP::Post.new(request.path)
        @connection.request_write(req, body)
        req
      end     

      i = 0
      requests.zip(reqs).collect do |request, req|
        response_plain = @connection.request_read(req).body
        response       = response_plain.include?('<?xml') ? REXML::Document.new(response_plain) : response_plain
#        File.open("/home/quinn/response#{i += 1}.xml", 'w') { |f| f.write(response_plain) }
        request.parse(response)
      end
    end

public
    def query(request)
      res = do_request(request)
    end
    
    def queries(requests)
      do_requests(requests)
    end
  end
  
end
