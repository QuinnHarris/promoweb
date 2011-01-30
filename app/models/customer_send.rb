class CustomerSend < ActionMailer::Base
  helper ApplicationHelper
  helper OrderHelper
  
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
    send = CustomerSend.create_quote(order, task, subject, header)
    send.sender = SEND_EMAIL
    send.from = primary_email
    send.reply_to = [primary_email, secondary_email] if secondary_email
    send.to = customer_email
    CustomerSend.deliver(send)
    
    # To Company
    send.from = SEND_EMAIL
    send.reply_to = customer_email
    send.to = primary_email
    send.cc = secondary_email if secondary_email
    send.subject = "#{task.customer ? '!!! ' : ''}#{send.subject} - [#{task.user ? task.user.name : 'Customer'}]"
    CustomerSend.deliver(send)
  end

  def quote(order, task, subject, header)
    subject "#{subject} (\##{order.id})"
    header_text = header

    waiting_tasks = order.tasks_allowed(%w(Customer))

    content_type "multipart/mixed" 
  
    part "multipart/alternative" do |m|
      m.part :content_type => "text/plain",
           :body => render_message("quote_txt", :task => task, :order => order, :user => task.user, :header_text => header_text)
      
      m.part :content_type => "text/html",
           :body => render_message("quote_html", :task => task, :order => order, :user => task.user, :header_text => header_text, :waiting_tasks => waiting_tasks)
    end

#    unless order.invoices_ref.empty?
      @order = order
      attachment :content_type => "application/pdf", :filename => (order.invoices_ref.empty? ? "MOP Quote" : "MOP Invoice (#{order.id}-#{order.invoices_ref.count}).pdf"),
      :body => WickedPdf.new.pdf_from_string(render(:file => '/order/invoices', :layout => 'print', :body => { } ))
#    end
  end
end
