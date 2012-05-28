OrderTask

module OrdersHelper
  def submit_options(commit = true)   
    output = []
    inject = [controller.class.send("#{params[:action]}_tasks").first]
    inject << RequestOrderTask if @user

    if @order.task_ready?(RequestOrderTask, inject.uniq)
      text = @user ? "Submit Revised" : "Submit"
      text += (@order.task_completed?(PaymentInfoOrderTask) ? ' Order' : ' Quote Request')
      text += ' Again' if @order.task_performed?(RequestOrderTask)
      output << submit_tag(text, :id => 'submitbtn', :class => 'button')
    end
    
    inject << RequestOrderTask
    if task = @order.task_next(@permissions, inject.uniq) { |t| t.uri } and
      output << submit_tag("Continue to #{task.status_name}", :id => 'nextbtn', :class => 'button')
    elsif commit and (!@static or @user)
      output << submit_tag("Commit")
    end
    
    output.join('<br/>or to submit as a complete order<br/>')
  end
  
  def task_button(object, hash)
    hash.collect do |name, task|
      submit_tag(name) if object.task_ready?(task)
    end
  end
  
  def link_to_task(name, task, order = @order, options = {}, html_options = {})
    if task.uri
      # Nasty kludge as controller sometimes doesn't have a /.  Don't know why, should make uri mutable
      linked = task.uri.merge(:id => order.id).merge(options)
      linked.merge!(:controller => '/' + linked[:controller]) unless linked[:controller][0] == '/'
      link_to(name, linked, html_options.merge(:class => @user && task.late && 'late'))
    else
      if @user && task.late
        "<span class='late'>#{name}</span>"
      else
        name
      end
    end
  end

  def li_to_order(name, method = nil, list = nil)
    method ||= "#{name.downcase}_order"
    li_to_cur(name,
              send("#{method}_path", @order),
              [list].flatten.compact.collect { |m| send("#{m}_path", @order) })
  end
  
  def format_time_course(time)
    now = Time.now
    if time.year == now.year and
       time.month == now.month and
       time.day == now.day
       
      time.strftime("%I:%M %p")
    else
      time.strftime("%A %b %d" + ((time.year != now.year) ? " %Y" : ''))
    end
  end

  def valid?(object, method)
    object and object.respond_to?(method) and object.send(method) and !object.send(method).strip.empty?
  end
  
  def render_partial_null(partial_path, local_assigns = nil)
    begin
      logger.info("Partial: #{partial_path.inspect}")
      render :partial => partial_path, :locals => local_assigns
    rescue ActionView::MissingTemplate
    end
  end
  
  def text_field_predicated(object_name, method, options = {})
    if @static
      instance_variable_get("@#{object_name}").send(method).to_s
    else
      if @search or @naked
        autocomplete_field object_name, method, send("autocomplete_#{object_name}_#{method}_admin_orders_path"), options
      else
        text_field object_name, method, options
      end
    end
  end
  
  def customer_field(name)
    str = '<td>' + text_field_predicated(:customer, name) + '</td>'
    str += '<td>' + @similar.send(name) + '</td>' if @similar
    str
  end
  

  # Lifted from https://github.com/alloy/complex-form-examples/blob/master/app/helpers/projects_helper.br
  def remove_child_link(f)
    f.hidden_field(:_destroy) + link_to(image_tag('remove.png'), "javascript:void(0)", :class => "remove_child")
  end
 
  def add_child_link(form_builder, association, options = {})
    name = image_tag('add.png') + " Add #{association.to_s.split('_').collect { |s| s.singularize.capitalize}.join(' ') }"
    
    template = form_builder.fields_for(association,
                                       options[:object] || form_builder.object.class.reflect_on_association(association).klass.new,
                                       :child_index => "in_dex") do |f|
      render(:partial => options[:partial] || association.to_s.singularize,
             :locals => {(options[:form_builder_local] || :f) => f})
    end.gsub(/\s+/, ' ')

    link_to(name, "javascript:void(0)", :class => "add_child", :"data-template" => template, :"data-association" => association)
  end
end
