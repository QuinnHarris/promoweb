class Commission < ActiveRecord::Base
  belongs_to :user
  
  %w(settled payed).each do |type|
    composed_of type.to_sym, :class_name => 'Money', :mapping => [type, 'units']
  end
end
