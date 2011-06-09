OrderTask

module OrderHelper
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
      link_to(name, task.uri.merge(:order_id => order.id).merge(options), html_options.merge(:class => @user && task.late && 'late'))
    else
      if @user && task.late
        "<span class='late'>#{name}</span>"
      else
        name
      end
    end
  end
    
  def form_for(object_name, *args, &proc)
    raise ArgumentError, "Missing block" unless block_given?
    options = args.extract_options!
    url = options.delete(:url) || {}
    url.merge!(:only_path => false, :protocol => "https://") unless request.protocol == "https://" or RAILS_ENV != "production"
    concat(form_tag(url, options.delete(:html) || {}), proc.binding)
    fields_for(object_name, *(args << options), &proc)
    concat('</form>', proc.binding)
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
  
  def text_field_predicated(object_name, method, complete_options = {})
    if @static
      instance_variable_get("@#{object_name}").send(method).to_s
    else
      if @search or @naked
        text_field_with_auto_complete object_name, method, {}, complete_options.merge({ :after_update_element => 'on_select', :url => { :action => "auto_complete_for_#{object_name}_#{method}", :customer_id => @order.customer } } )
      else
        text_field object_name, method
      end
    end
  end
  
  def customer_field(name, complete_options = {})
    str = '<td>' + text_field_predicated(:customer, name, complete_options) + '</td>'
    str += '<td>' + @similar.send(name) + '</td>' if @similar
    str
  end
  
  # Lifted and modified from calendariffic plugin
  def calendar_input(text_name, text_value, text_attributes={}, image_attributes={}, id_suffix = '')
    image_name = 'start_cal'+id_suffix
    image_attributes[:name] = image_name if image_name
    image_attributes[:id] = image_name if image_name
    date_format = '%Y-%m-%d' #'%m/%d/%y'

    text_value = Date.today.strftime(date_format) if text_value.to_s.upcase.eql? 'TODAY'
    imt = image_tag('date.png', image_attributes)
    id_name = sanitize_to_id(text_name) + id_suffix
    tft = text_field_tag(text_name, text_value, text_attributes.merge(:id => id_name))
    script = %(<script language='javascript'>
Calendar.setup({
  inputField : '#{id_name}',
  ifFormat : '#{date_format}',
  button : '#{image_name}',
  weekNumbers : false,
  range : [#{yr = Time.now.year}, #{yr+1}],
/*  disableFunc : function (date) { var ref = new Date(); return date.getTime() < ref.getTime(); }*/
});
</script>)
    
    "#{tft}#{imt}#{script}"
  end

  def calendar_input_time(text_name, text_value, text_attributes={}, image_attributes={}, id_suffix = '')
    image_name = 'start_cal'+id_suffix
    image_attributes[:name] = image_name if image_name
    image_attributes[:id] = image_name if image_name
    date_format = '%Y-%m-%d %H:%M' #'%m/%d/%y'

    text_value = Date.today.strftime(date_format) if text_value.to_s.upcase.eql? 'TODAY'
    imt = image_tag('date.png', image_attributes)
    id_name = sanitize_to_id(text_name) + id_suffix
    tft = text_field_tag(text_name, text_value, text_attributes.merge(:id => id_name))
    script = %(<script language='javascript'>
Calendar.setup({
  inputField : '#{id_name}',
  ifFormat : '#{date_format}',
  showsTime : true,
  button : '#{image_name}',
  weekNumbers : false,
  range : [#{yr = Time.now.year}, #{yr+1}],
/*  disableFunc : function (date) { var ref = new Date(); return date.getTime() < ref.getTime(); }*/
});
</script>)
    
    "#{tft}#{imt}#{script}"
  end


  # Lifted from https://github.com/alloy/complex-form-examples/blob/master/app/helpers/projects_helper.rb
  # CHANGE FOR RAILS 3
  def remove_link(fields)
    out = ''
    out << fields.hidden_field(:_destroy)
    out << link_to_function(image_tag('remove.png'), "$(this).up('.#{fields.object.class.name.underscore}').hide(); $(this).previous().value = '1'")
    out
  end
  
  # These use the current date, but they could be lots easier.
  # Maybe just keep a global counter which starts at 10 or so.
  # That would be good enough if we only build 1 new record in the controller.
  #
  # And this of course is only needed because Ryan's example uses JS to add new
  # records. If you just build a new one in the controller this is all unnecessary.
  
  def add_phone_link(cust)
    link_to_function "#{image_tag 'add.png'} Add Phone Number" do |page|
      temp = render(:partial => 'phone_number', :locals => { :customer => cust, :phone_number => PhoneNumber.new })
      logger.info "Temp: #{temp}"
      page << %{var new_id = "new_" + new Date().getTime();
$('phone_numbers').insert({ bottom: "#{escape_javascript temp}".replace(/new_\\d+/g, new_id) });
}
    end
  end
end
