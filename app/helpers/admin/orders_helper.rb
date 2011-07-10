module Admin::OrdersHelper
  include OrderHelper
  
  def format_email(mail, name)
    return nil unless mail.send(name)
    mail.send(name).zip(mail.send("#{name}_addrs")).collect do |email, full|
      mail_to(email, full)
    end.join(', ')
  end
end
