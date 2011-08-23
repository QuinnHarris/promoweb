class DecorationPriceEntry < ActiveRecord::Base
  belongs_to :group, :class_name => 'DecorationPriceGroup', :foreign_key => 'group_id'
  belongs_to :fixed, :class_name => 'PriceGroup', :foreign_key => 'fixed_id'
  belongs_to :marginal, :class_name => 'PriceGroup', :foreign_key => 'marginal_id'

  %w(fixed_price_fixed fixed_price_marginal marginal_price_fixed marginal_price_marginal).each do |name|
    composed_of name.to_sym, :class_name => 'Money', :mapping => [name, 'units'], :allow_nil => true
  end
  
  def multiplier(name, unit)
    ((unit - 1 - self["#{name}_offset"]) / self["#{name}_divisor"]).floor || 0
  end
    
  def price_at(unit, count)
    base = (fixed_price_marginal * (1 + fixed_price_const * (count ** fixed_price_exp)))

    marginal = (marginal_price_marginal * (1 + marginal_price_const * (count ** marginal_price_exp)))
    base += marginal * multiplier('marginal', unit)
    
    fixed = fixed_price_fixed + marginal_price_fixed * multiplier('fixed', unit)
  
    PricePair.new(base, fixed)
  end
  
  
  def cost_at(unit, count)
    myfixed = fixed.price_entry_at(count)
    mymarginal = marginal ? marginal.price_entry_at(count) : PriceEntry.new

    themarginal = myfixed.marginal
    themarginal += mymarginal.marginal * multiplier('marginal', unit) unless mymarginal.marginal.nil?

    thefixed = myfixed.fixed
    thefixed += mymarginal.fixed * multiplier('fixed', unit) unless mymarginal.fixed.nil?

    PricePair.new(themarginal, thefixed)
  end
end
