require 'money/money'

class Money
  def initialize(units, currency = Money.default_currency, bank = Money.default_bank, multiplier = Money.default_multiplier)
    if units.is_a?(String)
      @units = Integer(units)
    elsif units.is_a?(Float)
      @units = Integer(units * multiplier + 0.5)
    else
      @units = units.round
    end
    @currency = currency
    @bank = bank
    @multiplier = Integer(multiplier)
  end
  
  
  # Handle nil == correctly
  def ==(other)
    return nil? unless other
    return units == other.units if other.is_a?(Money)
    units == other
  end

  def round_cents
    return self if nil?
    mult = (@multiplier / 100).to_i
    Money.new((@units / mult.to_f).round * mult)
  end
      
  def nil?
    @units.nil?
  end
  
  def min
    self
  end
  
  def max
    self
  end

  def abs
    Money.new(@units.abs, @currency, @bank, @multiplier)
  end
    
  def to_perty
    negative = (@units < 0)
    positive_units = negative ? -@units : @units

    digits = decimal_digits
    digits = 2 if (positive_units % (multiplier / 100)) == 0

    formatted = sprintf("%.#{digits}f", positive_units.to_f / multiplier)

    formatted.gsub!(/(\d)(?=\d{3}+(?:\.|$))(\d{3}\..*)?/,'\1,\2')

    return (negative ? '-' : '') + '$' + formatted
  end
  
  def inspect
    "<#{to_s} #{@currency}>"
  end
end

class MyRange
  def initialize(min, max = nil)
    if max
      @min, @max = (min < max) ? [min, max] : [max, min]
    else
      @min = @max = min
    end
  end
  
  def to_i
    nil
  end
  
  attr_accessor :min, :max
  
  %w(to_s to_perty).each do |name|
    define_method name do
      if min and max
        if min == max
          min.send(name)
        else
          "#{min.send(name)} to #{max.send(name)}"
        end
      else
        "CALL"
      end      
    end
  end
  
  def single
    return @min if @min == @max
    return nil
  end
  def cents
    money = single
    return nil unless money
    money.cents
  end

  def zero?
    single && @min.zero?
  end
  
  def nil?
    min.nil? and max.nil?
  end
  
  def +(r)
    MyRange.new(min + r.min, max + r.max)
  end

  def -(r)
    MyRange.new(min - r.min, max - r.max)
  end
  
  def *(m)
    MyRange.new(min && (min * m), max && (max * m))
  end
  
  def /(m)
    MyRange.new(min && (min / m), max && (max / m))
  end

  def round_cents
    MyRange.new(@min.round_cents,
                @max.round_cents)
  end
end


class PricePair
  private
  def adjust_value(val)
    (val.nil? || val.is_a?(Money) || val.is_a?(MyRange)) ? val : Money.new(val)
  end
  public

  def initialize(marginal, fixed)
    @marginal, @fixed = adjust_value(marginal), adjust_value(fixed)
  end
  
  attr_reader :marginal, :fixed
  
  def marginal=(val)
    @marginal = adjust_value(val)
  end

  def fixed=(val)
    @fixed = adjust_value(val)
  end
  
  def to_h
    { 'marginal' => @marginal.to_i, 'fixed' => @fixed.to_i }
  end
  
  def nil?
    @marginal.nil? and @fixed.nil?
  end
  
  def merge(rhs)
    PricePair.new(rhs.marginal.nil? ? @marginal : rhs.marginal,
                  rhs.fixed.nil? ? @fixed : rhs.fixed)
  end

  def round_cents
    PricePair.new(@marginal.round_cents,
                  @fixed.round_cents)
  end
end

# Sleezy trick to allow klass.new(x) to work for Fixnum
class Fixnum
  def self.new(val)
    val.to_i
  end
end
