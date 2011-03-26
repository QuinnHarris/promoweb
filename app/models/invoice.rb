class Invoice < ActiveRecord::Base
  has_many :entries, :class_name => 'InvoiceEntry', :foreign_key => 'invoice_id'
  belongs_to :order

  def total_item_price
    entries.inject(Money.new(0)) { |m, e| m += e.total_price }
  end
  extend ActiveSupport::Memoizable
  memoize :total_item_price

  def total_tax
    return 0.0 if tax_rate == 0.0
    (total_item_price * tax_rate).round_cents
  end

  def total_price
    total_item_price + total_tax
  end

  before_destroy :destroy_children
  def destroy_children
    entries.each { |e| e.destroy }
  end

  after_save :cascade_update
  def cascade_update
    order.push_quickbooks!
  end
end
