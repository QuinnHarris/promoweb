FAX_EMAIL = "fax@mountainofpromos.com"

class SupplierSend < ActionMailer::Base
helper OrderHelper
  helper ApplicationHelper
  helper OrderHelper

  def artwork(purchase, user, attachments = false)
    headers['return-path'] = SEND_EMAIL

    @po = purchase.purchase_order
    @groups = ArtworkGroup.find(:all, :conditions => { 'order_items.purchase_id' => purchase.id, 'artwork_tags.name' => 'supplier' }, :include => [{ :order_item_decorations => :order_item }, { :artworks => :tags }])

    if attachments
      @groups.collect { |g| g.artworks }.flatten.each do |artwork|
        next unless artwork.has_tag?('supplier')
        attachment({ :filename => artwork.art.original_filename,
                     :content_type => artwork.art.content_type,
                     :body => File.read(artwork.art.path) })
      end
    end

  end

  def purchase_order(purchase)
    @purchase = purchase
    headers['return-path'] = SEND_EMAIL
    
    unless purchase.fax?
      content_type "multipart/mixed" 
      part "multipart/alternative" do |m|
        m.part :content_type => "text/plain",
        :body => render_message("po_txt", :layout => 'print', :purchase => purchase)
        
        m.part :content_type => "text/html",
        :body => render_message("po_html", :purchase => purchase)
      end
    end

    attachment :content_type => "application/pdf", :filename => "MOP PO #{purchase.purchase_order.quickbooks_ref}.pdf",
      :body => WickedPdf.new.pdf_from_string(render(:file => '/admin/orders/po', :layout => 'print', :body => { } ))
  end

  def self.purchase_order_send(purchase, user)
    primary_email = purchase.order.user.email_string
    secondary_email = (purchase.order.user_id != user.id) && user.email_string

    # To Supplier
    send = self.create_purchase_order(purchase)
    if purchase.fax?
      send.from = FAX_EMAIL
      send.to = "#{purchase.supplier.fax}@rcfax.com"
    else
      send.from = primary_email
      send.reply_to = [primary_email, secondary_email] if secondary_email
      send.to = purchase.supplier.send_email
    end
    send.to = SEND_EMAIL unless RAILS_ENV == "production"
    send.subject = "PO-#{purchase.purchase_order.quickbooks_ref} / Mountain Xpress Promotions"
    self.deliver(send)

    
    # To Self
    send.from = purchase.fax? ? FAX_EMAIL : SEND_EMAIL
    send.reply_to = send.to
    send.to = primary_email
    send.cc = secondary_email if secondary_email
    send.subject = "PO-#{purchase.purchase_order.quickbooks_ref} Supplier PO [#{user.name}]"
    self.deliver(send) 
  end

  def self.artwork_send(purchase, user)
    primary_email = purchase.order.user.email_string
    secondary_email = (purchase.order.user_id != user.id) && user.email_string

    supplier_email = purchase.supplier.artwork_email
    supplier_email = SEND_EMAIL unless RAILS_ENV == "production"

    # To Self
    send = self.create_artwork(purchase, user)
    send.from = SEND_EMAIL
    send.reply_to = supplier_email
    send.to = primary_email
    send.cc = secondary_email if secondary_email
    send.subject = "PO-#{purchase.purchase_order.quickbooks_ref} Supplier Artwork [#{user.name}]"
    self.deliver(send)

    # To Supplier
    send = self.create_artwork(purchase, user, true)
    send.from = primary_email
    send.reply_to = [primary_email, secondary_email] if secondary_email
    send.to = supplier_email
    send.subject = "PO-#{purchase.purchase_order.quickbooks_ref} Artwork / Mountain Xpress Promotions"
    self.deliver(send)
  end
end
