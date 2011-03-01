module Admin::OrdersHelper
  include OrderHelper
  
  def format_email(mail, name)
    return nil unless mail.send(name)
    mail.send(name).zip(mail.send("#{name}_addrs")).collect do |email, full|
      mail_to(email, full)
    end.join(', ')
  end

  def format_supplier_info(supplier)
    elems = []
    elems << link_to('Website', "http://#{supplier.web}") unless supplier.web.blank?
    elems << format_phone(supplier.phone) if supplier.phone
    elems << "FAX: #{format_phone(supplier.fax)}" if supplier.fax
    elems << mail_to(supplier.send_email(@order.sample))
    elems.join(' ')
  end
end
