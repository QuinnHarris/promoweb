class PriceSource < ActiveRecord::Base
  has_one :supplier
  has_many :price_groups, :foreign_key => 'source_id'
  
  def self.get_by_name(name)
    source = find_by_name(name)
    return source if source
    create({:name => name})
  end
end
