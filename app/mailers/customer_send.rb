class CustomerSend < ActionMailer::Base
  helper ApplicationHelper
  helper OrdersHelper
  
  def self.controller_path
    "../order"
  end
  
  def self.dual_send(task, subject, header)
    order = task.object
    order = order.order if order.respond_to?(:order)
    raise "Expected Order object" unless order.is_a?(Order)

    if order.user
      primary_email = order.user.email_string
      secondary_email = (task.user && (task.user != order.user)) && task.user.email_string
    else
      if task.user
        primary_email = task.user.email_string
      else
        logger.info("User task send without order user")
        primary_email = SEND_EMAIL
      end
      secondary_email = nil
    end
    
    customer_email = order.customer.email_string
    customer_email = SEND_EMAIL unless RAILS_ENV == "production"
  
    # To Customer
    send = CustomerSend.quote(order, task, subject, header)
    send.sender = SEND_EMAIL
    send.from = primary_email
    send.reply_to = [primary_email, secondary_email] if secondary_email
    send.to = customer_email
    send.deliver
    
    # To Company
    send.from = SEND_EMAIL
    send.reply_to = customer_email
    send.to = primary_email
    send.cc = secondary_email if secondary_email
    send.subject = "#{task.customer ? '!!! ' : ''}#{send.subject} - [#{task.user ? task.user.name : 'Customer'}]"
    send.deliver
  end

  def quote(order, task, subject, header)
    @header_text = header
    @waiting_tasks = order.tasks_allowed(%w(Customer))
    @task = task
    @order = order

    if task.is_a?(ArtPrepairedOrderTask)
      size = 6*1024*1024*3/4
      order.artwork_proofs.sort_by { |a| a.art.size }.each do |artwork|
        size -= artwork.art.size
        break if size < 0
        attachments[artwork.art.original_filename] = File.read(artwork.art.path)
      end
    else #if !order.invoices_ref.empty?
      attachments[order.invoices_ref.empty? ? "MOP Quote.pdf" : "MOP Invoice (#{order.id}-#{order.invoices_ref.count}).pdf"] = WickedPdf.new.pdf_from_string(render(:file => '/orders/invoices', :layout => 'print', :body => { } ))
    end

    mail(:subject => "#{subject} (\##{order.id})") do |format|
      format.text
      format.html
    end
  end
end
