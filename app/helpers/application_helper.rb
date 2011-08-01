# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def error_messages_for_many(object_list, options = {})
    options = options.symbolize_keys
    objects = object_list.collect { |obj| instance_variable_get("@#{obj}") }.compact
    error_count = objects.inject(0) { |sum, o| sum + o.errors.count }
    if error_count > 0
      content_tag("div",
        content_tag(
          options[:header_tag] || "h2",
          "#{pluralize(error_count, "error")} prohibited this from being saved"
        ) +
        content_tag("p", "There were problems with the following fields:") +
        content_tag("ul",
          objects.collect { |obj| obj.errors.full_messages.collect { |msg| content_tag("li", msg) } }.flatten),
        "id" => options[:id] || "errorExplanation", "class" => options[:class] || "errorExplanation"
      )
    else
      ""
    end
  end

  def format_time_tod(time)
    time.strftime(" %I:%M %p")
  end

  def format_time_abs(time, tod = true)
    str = time.strftime("%A %b %d, %Y")
    str += format_time_tod(time) if tod
    str
  end
  
  def format_time(time, tod = true)
    return "UNKNOWN" unless time
    now = Time.now
    if time.year == now.year
      if time.yday == now.yday
        str = "Today"
      elsif time.yday == (now.yday - 1)
        str = "Yesterday"
      else
        str = time.strftime("%A %b %d")
      end
    else
      str = format_time_abs(time, false)
    end
    str += format_time_tod(time) if tod
    str
  end

  def format_phone(number)
    if /^1?(\d{3})(\d{3})(\d{4})$/ === number.to_s
      "#{$1}-#{$2}-#{$3}"
    else
      number
    end
  end
  
  def render_menu
    "<ul class='menu'>" +
    @@menu_list.collect do |name, action|
      '<li>' + link_to(name, :action => action) + '</li>'
    end.join +
    '</ul>'
  end
  
  def path_to_category(category)
    path = category.path_web
    path += %w(price 1) unless category.children
    path
  end
    
  def link_to_category(category)
    link_to(category.name, url_for({
      :controller => '/categories',
      :action => 'main',
      :path => path_to_category(category)}.merge(:columns => session[:columns], :rows => session[:rows])))
  end
  
  def render_categories(path, cont = true)
    str = '<ul>'
    path.first.children.sort { |l, r| l.name <=> r.name }.each do |child|
      match = (path[1] == child)
      str += match ? '<li class="sel">' : '<li>'
      str += link_to_category child
      if (match or (cont && !@robot)) and child.children and !child.children.empty?
        str += render_categories(match ? path[1..-1] : [child], match)
      end
      str += '</li>'
    end
    str += '</ul>'
    str
  end
  
  def get_rendered_categories
    render_categories([Category.root] + (@category ? @category.path_obj_list : []))
  end
  
  def category_path(category)
    res = category.path_obj_list.collect do |comp|
      link_to_category(comp)
    end.join(' > ')
    res += link_to image_tag('remove.png'), { :controller => '/admin/categories', :action => :remove_product, :id => @product, :category => category.id }, :confirm => "Remove #{@product.name} from #{category.path}" if @user and @product
    res
  end
  
  def path_name(category = @category)
    return '!!! CHECK AVAILABILITY AND PRICE !!!' unless category

    text = []

    if @context
      if @context[:children]
        text << link_to('All', {
                          :controller => '/categories',
                          :action => 'main',
                          :path => category.path_web + [@context[:sort], '1'] })
      elsif @exclusive
        text << "Misc"
      end
      
      if @context[:tag]
        text << image_tag("tags/#{@context[:tag].downcase}.png", :alt => "#{@context[:tag]} Icon") +
          link_to(@context[:tag], {
                    :controller => '/categories',
                    :action => 'main',
                    :path => category.path_web + [@context[:tag], @context[:sort], '1'] })
      end
    end

    category_path(category) + (text.empty? ? '' : " : #{text.join(' : ')}")
  end
  
  def product_count
    return '' unless @category
    "<span id=\"num\">#{@category.count_products(@context || {})} Products</span>"
  end
  
  def path_text
    product_count +
    '<h1 id="path">' +
    path_name +
    '</h1>'
  end
  
  def url_for_product(product, category = nil, options = nil) # tag, order, include_children
    url_prop = { :controller => '/products', :action => 'show', :id => product.web_id }
    unless @robot
      url_prop.merge!( :category => category ) if category
      url_prop.merge!(options) if options
    end
    url_for url_prop    
  end
    
  def print_list(list, type = 'or')
    str = list[0..-2].join(', ')
    str += " #{type} " if list.length > 1
    str += list[-1].to_s unless list.empty?
    str    
  end
  
  def li_to(name, url_h, cls = nil)
    selected = block_given? ? yield : ((params[:action] == url_h[:action].to_s) and (params[:controller] == url_h[:controller][1..-1]))
    url_h = url_h.merge({:only_path => false, :protocol => "https://"}) unless request.protocol == "https://" or RAILS_ENV != "production"
    url_h = url_h.merge(:order_id => @order.id) if @order
    (selected ? "<li class='sel #{cls}'>" : (cls ? "<li class='#{cls}'>" : '<li>')) +
    link_to(name, url_h) + '</li>'
  end
  
  def allowed?(roles)
    return true if @permissions and @permissions.include?('Super')
    not ((@permissions || []) & [roles].flatten).empty?
  end
  
  def li_to_task(name, task)
    return li_to(name, task.uri) if allowed?(task.roles)
    ''
  end

  # Only used by access but broadly usefull
  def split_by_common(list)
    result = []
    last_value = nil
    first = true
    list.each do |elem|
      value = yield elem
      if first or value != last_value
        last_value = value
        result << [value, [elem]]
        first = false
      else
        result.last.last << elem
      end
    end
    result
  end
end
