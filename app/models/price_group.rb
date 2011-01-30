class PriceGroup < ActiveRecord::Base
  has_many :price_entries, :order => 'minimum'

  has_and_belongs_to_many :variants
  
  belongs_to :source, :class_name => 'PriceSource', :foreign_key => 'source_id'
  has_many :decoration_price_entry_fixed, :class_name => 'DecorationPriceEntry', :foreign_key => 'fixed_id'
  has_many :decoration_price_entry_marginal, :class_name => 'DecorationPriceEntry', :foreign_key => 'marginal_id'
  has_many :order_items
  
  def price_entry_at(n)
    entry = price_entries.find(:first,
                               :conditions => ["minimum <= ? AND marginal IS NOT NULL", n],
                               :order => "minimum DESC")
    return entry.price if entry
    return PricePair.new(nil, nil)
  end
  
  def minimum
    entry = price_entries.find(:first,
                               :conditions => "fixed IS NULL OR fixed = 0",
                               :order => "minimum")
    entry && entry.minimum
  end
  
  def pricing(quantity = nil)
    Product
    PriceSet.new(self, Money.new(coefficient.to_f || 1.0), exponent || -0.5, quantity)
  end
  
  def diff_prices(dst)
    src = price_entries.to_a
    count = src.length    
    dst.each do |d|
      return true unless src.find { |s| not d.find { |k, v| s.send(k) != v } }
      count -= 1;
    end
    return count != 0
  end
  
  def create_prices(dst)
#    puts "KLUDGE: #{print_prices}"
    price_entries.collect { |e| }
    dst.collect { |hash| price_entries.create(hash) }
  end
  
  def update_prices(dst)
    # What about reusing existing entries?
    price_entries.each { |pe| pe.destroy }
    price_entries.target = []
    create_prices(dst)
  end
  
  def self.create_prices(dst, src = nil)
    grp = create(src ? {:source_id => src} : nil)
    grp.create_prices(dst)
    grp
  end
  
  def print_prices
    price_entries.collect do |entry|
      "#{entry.minimum.to_s.rjust(3)}: " + ("#{entry.fixed.to_s.rjust(6)}+") + "#{entry.marginal.to_s.rjust(6)}"
    end.join(',   ')
  end
  
  before_destroy :destroy_price_entries
  def destroy_price_entries
    price_entries.each { |entry| entry.destroy }
  end
end
