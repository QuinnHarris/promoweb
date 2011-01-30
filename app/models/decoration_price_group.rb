class DecorationPricing
  def initialize(group, unit, limit, count)
    @group, @unit, @limit, @count = group, unit, limit, count
  end
  
  def entry_at(entries)
    entries.reverse.each do |entry|
      return entry if entry.minimum <= @unit
    end
    return nil
  end
  
  def get(type)
    entries = @group.entries
    if @unit
      entry = entry_at(entries)
      return nil unless entry
      entry.send("#{type}_at", @unit, @count)
    else
      min = entries.first.send("#{type}_at", @group.entries.first.minimum, @count)
      # FIX ME!!!!
      max = entries.last.send("#{type}_at", @limit, @count)
      PricePair.new(MyRange.new(min.marginal, max.marginal),
                    MyRange.new(min.fixed, max.fixed))
    end
  end
  
#  %w(price cost).each do |type|
#    define_method type do
#      res = instance_variable_get("@#{type}")
#      return res if res
#      res = if @unit
#        entry = entry_at
#        return nil unless entry
#        entry.send("#{type}_at", @unit, @count)
#      else
#        min = @group.entries.first.send("#{type}_at", @group.entries.first.minimum, @count)
#        # FIX ME!!!!
#        max = @group.entries.last.send("#{type}_at", @limit, @count)
#        # max = entries.last.fixed_at(technique.unit_limit)
#        #puts "#{min} - #{max}"
#        MyRange.new(min, max)
#      end
#      instance_variable_set("@#{type}", res)
#      return res
#    end
#  end
  
  def price
    return @price if @price
    @price = get('price').round_cents
  end
  
  def cost
    return @cost if @cost
    @cost = get('cost').round_cents
  end
end

class DecorationPriceGroup < ActiveRecord::Base
  belongs_to :technique, :class_name => 'DecorationTechnique', :foreign_key => 'technique_id'
  belongs_to :supplier
  has_many :entries, :class_name => 'DecorationPriceEntry', :foreign_key => 'group_id', :order => 'minimum'
  
  def pricing(unit, limit, count)
    DecorationPricing.new(self, unit, limit, count)
  end
end
