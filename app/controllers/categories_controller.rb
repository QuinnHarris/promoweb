class LinkRenderer < WillPaginate::ActionView::LinkRenderer
  def page_number(page)
    text = @options[:page_names] ? @options[:page_names][page-1] : page.to_s
    unless page == current_page
      link(text, page, :rel => rel_value(page))
    else
      tag(:em, text, :class => 'current')
    end
  end

  def add_current_page_param(url_params, page)
    url_params[:path] = url_params[:path].split('/')[0...-1] + [page]
  end
end


class CategoriesController < ApplicationController
  before_filter :setup_context

  #caches_page :main, :home

  @@featured_items = 4
  cattr_reader :featured_items

private
  def sitemap_recurse(root, exclusive = false, list = []) 
    base = (["http://www.mountainofpromos.com/categories"] + root.path_web).join('/')
    list << { :loc => base}
    
    ([nil] + root.products_tags({:children => !exclusive})).each do |tag|
      total = root.count_products({
        :children => !exclusive,
        :tag => tag
      })
      pages = (total.to_f / (@@columns * @@rows)).ceil

      Category.order_list.each do |order|
        pages.times do |page|
          list << { :loc => 
            (["http://www.mountainofpromos.com/categories"] + root.path_web +
            [exclusive ? 'exclusive' : nil, tag, "#{order}/#{page+1}"]).compact.join('/') }
        end
      end
    end
    
    unless exclusive
      if root.count_products > 0 and root.children.count > 0
        sitemap_recurse(root, true, list)
      end
      
      root.children.each do |child|
        sitemap_recurse(child, false, list)
      end if root.children
    end
    
    list
  end
public
  
  # Google sitemap
  def sitemap
    headers['Content-Type'] = 'text/xml; charset=utf-8'  
    @links = sitemap_recurse(Category.root)
    render :template => 'sitemaps/sitemap', :layout=>false
  end

  def map

  end

  @@columns = 4
  @@rows = 5
#  if RAILS_ENV != "production"
#    @@columns = 6
#    @@rows = 10
#  end
  cattr_reader :columns, :rows
  

  # The ruby way, show as mooolasis
  def home
    @title = "Mountain of Promotions - Custom imprinted products"
    @description = "Mountain of Promotions"

    @per_page = @@columns * @@rows

    @purposes = ['employee recognition', 'corporate gifts', 'product promotions', 'school promotions', 'educational aids', 'health and wellness programs', 'safety awareness', 'staff recognition', 'appreciation gifts']
    @keywords = ('custom imprinted embroidered debosed products ' + @purposes.join(' ')).split(' ').uniq.join(' ')

    list = []
    %w(Special Closeout).each do |tag_name|
      list += Category.root.children.collect do |cat|
        [cat, tag_name, cat.count_products(:children => true, :tag => tag_name)]
      end.sort_by { |cat, tag, count| count }.reverse[0...6]
    end

    @categories = list.sort_by { |cat, tag, count| count }[0...8].sort_by { |cat, tag, count| cat.name }

    OrderTask
    @reviews = ReviewOrderTask.find(:all, :order => 'id DESC', :limit => 10, :conditions => { :active => true })
    @reviews.delete_if do |review|
      next !review.publish unless review.publish.nil?
      false
#      sum = 0
#      num = 0
#      ReviewOrderTask.aspect_methods.each do |method|
#        rate = review.send(method).to_i
#        next unless rate
#        num += 1
#        sum += rate
#        sum = -100 if rate < 3
#      end
#      next true if sum <= (num * 3)
    end
  end

  # redirect to appropriate method
  def main
    @javascripts = ['rails.js', 'effects', 'controls'] if @user
    
    @path = params[:path] ? params[:path].split('/') : []
    
    # Split @path and tail at meta point
    tail = nil
    (Tag.names + Category.order_list).find do |t|
      if idx = @path.index(t)
        tail = @path[(idx)..-1]       
        @path = @path[0...idx]
        next true
      end
    end
    
    @path_web = @path    
    @path = @path.collect { |p| p.gsub('_',' ') }
    
    @exclusive = @path.last == 'exclusive'
    children = !(@exclusive && @path.pop)
    raise ::ActionController::RoutingError, "Meta category exclusive must be used with tail" if !children and !tail
       
    # Find Category
    @category = Category.find_by_path(@path)
    raise ::ActionController::RoutingError, "Category does not exist: #{@path.join('/')}" unless @category
    raise ::ActionController::RoutingError, "Category exclusive only applies to categories with children" unless children or @category.children.count > 0
       
    @title = "Custom #{@category.name} - Logo Imprinted Promotional Products"
    
    @columns = [(params[:columns] && params[:columns].to_i > 0) ? params[:columns].to_i : nil, session[:columns], @@columns].compact.first
    session[:columns] = @columns if session[:columns] || @columns != @@columns
    @rows = [(params[:rows] && params[:rows].to_i > 0) ? params[:rows].to_i : nil, session[:rows], @@rows].compact.first
    session[:rows] = @rows if session[:rows] || @rows != @@rows
    @per_page = @columns * @rows

    @context = {
      :children => children,
      :sort => 'price',
    }
    
    if tail
      list(tail)
    else
      categories
    end
  end
  
private
  def categories
    # Redirect to list view if category doesn't have children
    if @category.children.count == 0
      redirect_to :path => @path_web + %w(price 1)
      return
    end

    @per_page = @@columns * @@rows
    
    @direct_children = @category.children.sort { |l, r| l.name <=> r.name }
    direct_children_names = @direct_children.collect { |c| c.name }.join(', ')

    @context[:children] = false
    
    @email_subject = @category.name
    
    @description = "#{@category.name} including "
    @description += direct_children_names
    @description += ".  All products can be custom imprinted."
    
    @keywords = "#{@category.name} #{direct_children_names}"
  
    render :action => :categories
  end

  def list(tail)
    @path_tail = @path_web + tail[0...-1]

    # Parse and validate path tail
    @context.merge!(:tag => tail.shift) if Tag.names.include?(tail.first)

    raise ::ActionController::RoutingError, "Sort order required" if tail.empty?
    sort = tail.shift
    raise ::ActionController::RoutingError, "Sort order must be #{Category.order_list.join(', ')}" unless Category.valid_order?(sort)
    @context.merge!(:sort => sort)

    raise ::ActionController::RoutingError, "Page number required" if tail.empty?
    @page = tail.shift
    raise ::ActionController::RoutingError, "Page number must be numeric" unless @page.to_i.to_s == @page
    @page = @page.to_i
    raise ::ActionController::RoutingError, "Page number must be positive" unless @page > 0
  
    options = @context.merge({
      :page => @page,
      :per_page => @per_page
    })
       
    @products = @category.paginate_products(options)

    @paginate_options = {
      :renderer => 'LinkRenderer'
    }

    if sort == 'price'
      @page_names = @category.calculate_products_price_breaks(options).collect { |e| "#{e['min'].to_perty} &#8211; #{e['max'].to_perty}" }
      @paginate_options.merge!(:page_names => @page_names, :inner_window => 1)
    end    
    
    @email_subject = @category.name
    
    @description = "List of #{@products.total_entries} #{@category.name}"
    @description += ".  All products can be custom imprinted."

    render :action => :list
  end
end
