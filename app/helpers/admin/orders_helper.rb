module Admin::OrdersHelper
  include ::OrdersHelper
  
  def format_email(mail, name)
    return nil unless mail.send(name)
    mail.send(name).zip(mail.send("#{name}_addrs")).collect do |email, full|
      mail_to(email, full)
    end.join(', ')
  end

  # Kludge to fix autocomplete (REMOVE WITH JQuery Upgrade)
  def auto_complete_result(entries, field, phrase = nil)
    return unless entries
    render :partial => '/admin/orders/autocomplete', :locals => { :entries => entries, :field => field, :phrase => phrase }
  end
end
