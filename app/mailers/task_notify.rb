class TaskNotify < ActionMailer::Base
  helper ApplicationHelper
  helper OrderHelper
  
  def notify(order, task, recipients)
    @order, @task = order,task

    mail(:to => Rails.env.production? ? recipients : SEND_EMAIL,
         :from => SEND_EMAIL,
         :reply_to => (task.user ? task.user : order.customer).email_string,
         :subject => "<#{task.completed_name}> - [#{task.user ? task.user.name : 'Customer'}] (\##{order.id})")
  end
  
  def delegate(order, current_user, user)
    @order, @user = order, user
    @tasks = order.tasks_allowed_for_user(user)
    
    originators = [current_user, order.user].uniq.collect { |u| u.email_string }

    mail(:to => Rails.env.production? ? user.email : SEND_EMAIL,
         :from => SEND_EMAIL,
         :reply_to => originators,
         :cc => originators,
         :subject => "#{@tasks.collect { |t| t.waiting_name }.join(', ')} - [#{current_user.name}] (\##{order.id})")
  end

end
