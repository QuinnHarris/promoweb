class Invoice < ActiveRecord::Base
  has_many :entries, :class_name => 'InvoiceEntry', :foreign_key => 'invoice_id'
  belongs_to :order
  has_many :payment_transactions

  def total_item_price
    @total_item_price ||= entries.inject(Money.new(0)) { |m, e| m += e.total_price }
  end

  def tax_rate_s
    '%0.02f%' % (self.tax_rate * 100.0)
  end

  def total_tax
    return Money.new(0) if tax_rate == 0.0
    (total_item_price * tax_rate).round_cents
  end

  def total_price
    total_item_price + total_tax
  end

  def tax_rate_s
    '%0.02f%' % (self.tax_rate * 100.0)
  end

  def qb_sales_tax_id
    case tax_type
    when 'Colorado'
      '80000476-1300837712'
    when 'LaPlata'
      '80000710-1311095766'
    when 'Durango'
      '80000711-1311096268'
    else
      nil
    end
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
