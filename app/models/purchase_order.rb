class PurchaseOrder < ActiveRecord::Base
  belongs_to :purchase

  before_create :set_po_num
  def set_po_num
    last_po = PurchaseOrder.find(:first, :conditions => 'purchase_orders.quickbooks_ref IS NOT NULL', :order => 'quickbooks_ref DESC')

    unless /[QR](\d+)/ === last_po.quickbooks_ref
      raise "Unkown PO: #{last_po.quickbooks_ref}"
    end

    new_po = "R#{Integer($1)+1}"
    logger.info("Allocating PO: #{new_po}")
    self.quickbooks_ref = new_po
  end
end
