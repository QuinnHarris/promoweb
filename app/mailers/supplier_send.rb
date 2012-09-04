FAX_EMAIL = "fax@mountainofpromos.com"

class SupplierSend < ActionMailer::Base
  helper ApplicationHelper
  helper OrdersHelper

  def apply_artwork(purchase)
    @po = purchase.purchase_order
    @groups = ArtworkGroup.find(:all, :conditions => { 'order_items.purchase_id' => purchase.id, 'artwork_tags.name' => 'supplier' }, :include => [{ :order_item_decorations => :order_item }, { :artworks => :tags }])

    @groups.collect { |g| g.artworks }.flatten.each do |artwork|
      next unless artwork.has_tag?('supplier')
      next if artwork.art.size >= 7680000
      attachments[artwork.art.original_filename] = {
        :mime_type => artwork.art.content_type,
        :content => File.read(artwork.art.path, :encoding => 'BINARY') }
    end
  end

  def artwork(purchase)
    headers['return-path'] = SEND_EMAIL

    apply_artwork(purchase)

    mail do |format|
      format.text
      format.html
    end
  end

  def purchase_order(purchase)
    @purchase = purchase
    headers['return-path'] = SEND_EMAIL

    attachments["MOP PO #{purchase.purchase_order.quickbooks_ref}.pdf"] = WickedPdf.new.pdf_from_string(render(:file => '/admin/orders/po', :layout => 'print', :body => { } ))

    apply_artwork(purchase) if purchase.include_artwork_with_po?
    
    mail do |format|
      format.text
      format.html
    end
  end

  def self.both_send(purchase, user, method, subject, to, from = nil)
    primary_email = purchase.order.user.email_string
    secondary_email = (purchase.order.user_id != user.id) && user.email_string

    send = SupplierSend.send(method, purchase)

    # To Supplier
    send.from = from || primary_email
    send.reply_to = [primary_email, secondary_email] if secondary_email
    send.to = to
    send.to = SEND_EMAIL unless Rails.env.production?
    send.subject = "PO-#{purchase.purchase_order.quickbooks_ref} #{subject} / Mountain Xpress Promotions"
    send.deliver

    # To Self
    send.parts.delete_if { |p| p.attachment? }
    send.from = from || SEND_EMAIL
    send.reply_to = to
    send.to = primary_email
    send.cc = secondary_email if secondary_email
    send.subject = "PO-#{purchase.purchase_order.quickbooks_ref} Supplier #{subject} [#{user.name}]"
    send.deliver
  end

  def self.purchase_order_send(purchase, user)
    both_send(purchase, user, :purchase_order, 'Purchase Order',
              purchase.fax? ? "#{purchase.supplier.fax}@rcfax.com" : purchase.send_email,
              purchase.fax? ? FAX_EMAIL : nil)
  end

  def self.artwork_send(purchase, user)
    both_send(purchase, user, :artwork, 'Artwork',
              purchase.supplier.artwork_email)
  end
end
