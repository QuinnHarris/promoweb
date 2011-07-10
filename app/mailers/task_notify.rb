class TaskNotify < ActionMailer::Base
  helper ApplicationHelper
  helper OrderHelper
  
  def notify(order, task, recipients)
    recipients = SEND_EMAIL unless RAILS_ENV == "production"
      
    from       SEND_EMAIL # Always from system
    reply_to   (task.user ? task.user : order.customer).email_string
    recipients recipients
    
    subject    "<#{task.completed_name}> - [#{task.user ? task.user.name : 'Customer'}] (\##{order.id})"
    
    body       :order => order, :task => task
    content_type "text/html"
  end
  
  def delegate(order, current_user, user)
    waiting_tasks = order.tasks_allowed_for_user(user)

    recipient = user.email
    recipient = SEND_EMAIL unless RAILS_ENV == "production"
    
    originators = [current_user, order.user].uniq.collect { |u| u.email_string }
      
    from       SEND_EMAIL # Always from system
    reply_to   originators
    recipients recipient
    cc         originators
    
    subject    "#{waiting_tasks.collect { |t| t.waiting_name }.join(', ')} - [#{current_user.name}] (\##{order.id})"
    
    body       :order => order, :tasks => waiting_tasks, :user => user
    content_type "text/html"
  end

end
