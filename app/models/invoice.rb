class Invoice < ActiveRecord::Base
  has_many :entries, :class_name => 'InvoiceEntry', :foreign_key => 'invoice_id'
  belongs_to :order
  
  def total_price
    entries.inject(Money.new(0)) { |m, e| m += e.total_price }
  end

  before_destroy :destroy_children
  def destroy_children
    entries.each { |e| e.destroy }
  end
end
