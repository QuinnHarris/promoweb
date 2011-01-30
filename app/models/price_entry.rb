class PriceEntry < ActiveRecord::Base
  belongs_to :price_group
  
  composed_of :fixed, :class_name => 'Money', :mapping => %w(fixed units), :allow_nil => true
  composed_of :marginal, :class_name => 'Money', :mapping => %w(marginal units), :allow_nil => true
  
  composed_of :price, :class_name => 'PricePair', :mapping => [ ['marginal', 'marginal'], ['fixed', 'fixed'] ]
end
