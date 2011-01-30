require 'money/variable_exchange_bank'

# Represents an amount of money in a certain currency.
class Money
  include Comparable
  
  attr_reader :units, :currency, :bank, :multiplier
  
  class << self
    # Each Money object is associated to a bank object, which is responsible
    # for currency exchange. This property allows one to specify the default
    # bank object.
    #
    #   bank1 = MyBank.new
    #   bank2 = MyOtherBank.new
    #   
    #   Money.default_bank = bank1
    #   money1 = Money.new(10)
    #   money1.bank  # => bank1
    #   
    #   Money.default_bank = bank2
    #   money2 = Money.new(10)
    #   money2.bank  # => bank2
    #   money1.bank  # => bank1
    #
    # The default value for this property is an instance if VariableExchangeBank.
    # It allows one to specify custom exchange rates:
    #
    #   Money.default_bank.add_rate("USD", "CAD", 1.24515)
    #   Money.default_bank.add_rate("CAD", "USD", 0.803115)
    #   Money.us_dollar(100).exchange_to("CAD")  # => Money.ca_dollar(124)
    #   Money.ca_dollar(100).exchange_to("USD")  # => Money.us_dollar(80)
    attr_accessor :default_bank
    
    # The default currency, which is used when <tt>Money.new</tt> is called
    # without an explicit currency argument. The default value is "USD".
    attr_accessor :default_currency

    attr_accessor :default_multiplier
  end
  
  self.default_bank = VariableExchangeBank.instance
  self.default_currency = "USD"
  self.default_multiplier = 1000
  
  
  # Create a new money object with value 0.
  def self.empty(currency = default_currency)
    Money.new(0, currency)
  end

  # Creates a new Money object of the given value, using the Canadian dollar currency.
  def self.ca_dollar(units)
    Money.new(units, "CAD")
  end

  # Creates a new Money object of the given value, using the American dollar currency.
  def self.us_dollar(units)
    Money.new(units, "USD")
  end
  
  # Creates a new Money object of the given value, using the Euro currency.
  def self.euro(units)
    Money.new(units, "EUR")
  end
  
  def self.add_rate(from_currency, to_currency, rate)
    Money.default_bank.add_rate(from_currency, to_currency, rate)
  end
  
  
  # Creates a new money object. 
  #  Money.new(100) 
  # 
  # Alternativly you can use the convinience methods like 
  # Money.ca_dollar and Money.us_dollar 
  def initialize(units, currency = Money.default_currency, bank = Money.default_bank, multiplier = Money.default_multiplier)
    @units = units.round
    @currency = currency
    @bank = bank
    @multiplier = multiplier.to_i
  end

  def decimal_digits
    (Math.log(@multiplier)/Math.log(10)).ceil
  end

  # Do two money objects equal? Only works if both objects are of the same currency
  def ==(other_money)
    units == other_money.units && bank.same_currency?(currency, other_money.currency)
  end

  def <=>(other_money)
    if bank.same_currency?(currency, other_money.currency)
      other_units = other_money.units
    else
      other_units = other_money.exchange_to(currency).units
    end
    (units * other_money.multiplier) <=> (other_units * multiplier)
  end

  def +(other_money)
    if currency == other_money.currency
      other_units = other_money.units
    else
      other_units = other_money.exchange_to(currency).units
    end
    Money.new((units + other_units * (multiplier.to_f / other_money.multiplier.to_f)).to_i,currency)
  end

  def -(other_money)
    if currency == other_money.currency
      other_units = other_money.units
    else
      other_units = other_money.exchange_to(currency).units
    end
    Money.new((units - other_units * (multiplier.to_f / other_money.multiplier.to_f)).to_i,currency)
  end

  def -@
    Money.new(-@units)
  end


  # get the units value of the object
  def cents
    (@units * 100) / multiplier
  end

  # multiply money by fixnum
  def *(fixnum)
    Money.new((units * fixnum).to_i, currency)
  end

  # divide money by fixnum
  def /(fixnum)
    Money.new((units / fixnum).to_i, currency)
  end
  
  # Test if the money amount is zero
  def zero?
    units == 0
  end


  # Format the price according to several rules. The following options are
  # supported: :display_free, :with_currency, :no_cents, :symbol and :html
  #
  # display_free:
  #
  #  Money.us_dollar(0).format(:display_free => true) => "free"
  #  Money.us_dollar(0).format(:display_free => "gratis") => "gratis"
  #  Money.us_dollar(0).format => "$0.00"
  #
  # with_currency: 
  #
  #  Money.ca_dollar(100).format => "$1.00"
  #  Money.ca_dollar(100).format(:with_currency => true) => "$1.00 CAD"
  #  Money.us_dollar(85).format(:with_currency => true) => "$0.85 USD"
  #
  # no_cents:  
  #
  #  Money.ca_dollar(100).format(:no_cents => true) => "$1"
  #  Money.ca_dollar(599).format(:no_cents => true) => "$5"
  #  
  #  Money.ca_dollar(570).format(:no_cents => true, :with_currency => true) => "$5 CAD"
  #  Money.ca_dollar(39000).format(:no_cents => true) => "$390"
  #
  # symbol:
  #
  #  Money.new(100, :currency => "GBP").format(:symbol => "£") => "£1.00"
  #
  # html:
  #
  #  Money.ca_dollar(570).format(:html => true, :with_currency => true) =>  "$5.70 <span class=\"currency\">CAD</span>"
  def format(*rules)
    # support for old format parameters
    rules = normalize_formatting_rules(rules)
    
    if units == 0
      if rules[:display_free].respond_to?(:to_str)
        return rules[:display_free]
      elsif rules[:display_free]
        return "free"
      end
    end

    if rules.has_key?(:symbol)
      if rules[:symbol]
        symbol = rules[:symbol]
      else
        symbol = ""
      end
    else
      symbol = "$"
    end
    
    if rules[:no_cents]
      formatted = sprintf("#{symbol}%d", units.to_f / multiplier)
    else
      formatted = sprintf("#{symbol}%.#{decimal_digits}f", units.to_f / multiplier)
    end
    
    # Commify ("10000" => "10,000")
    formatted.gsub!(/(\d)(?=\d{3}+(?:\.|$))(\d{3}\..*)?/,'\1,\2')

    if rules[:with_currency]
      formatted << " "
      formatted << '<span class="currency">' if rules[:html]
      formatted << currency
      formatted << '</span>' if rules[:html]
    end
    formatted
  end  
  
  # Money.ca_dollar(100).to_s => "1.00"
  def to_s
    digits = decimal_digits
    digits = 2 if (units % (multiplier / 100)) == 0
    sprintf("%.#{digits}f", units / multiplier.to_f)
  end

  def to_i
    @units
  end

  def to_f
    units / multiplier.to_f
  end
  
  # Recieve the amount of this money object in another currency.
  def exchange_to(other_currency)
    Money.new(@bank.exchange(self.units, currency, other_currency), other_currency)
  end  
  
  # Recieve a money object with the same amount as the current Money object
  # in american dollar 
  def as_us_dollar
    exchange_to("USD")
  end
  
  # Recieve a money object with the same amount as the current Money object
  # in canadian dollar 
  def as_ca_dollar
    exchange_to("CAD")
  end
  
  # Recieve a money object with the same amount as the current Money object
  # in euro
  def as_euro
    exchange_to("EUR")
  end
  
  # Conversation to self
  def to_money
    self
  end
  
  private
  
  def normalize_formatting_rules(rules)
    if rules.size == 1
      rules = rules.pop
      rules = { rules => true } if rules.is_a?(Symbol)
    else
      rules = rules.inject({}) do |h,s|
        h[s] = true
        h
      end
    end
    rules
  end
end
