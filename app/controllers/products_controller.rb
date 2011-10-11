#class Context
#  def initialize(params)
#    @order = params[:order]
#    @order = 'name' unless @order
#    
#    @tag_name = params[:tag]
#    @include_children = params[:children]    
#    
#    raise ::ActionController::RoutingError, "Sort order must be #{Category.order_list.join(', ')}" unless Category.valid_order?(@order)
#  end
#  
#  attr_accessor :path, :tag_name, :order, :offset, :terms
#end

#class ProductSweeper < ActiveRecord::Observer
#  observe Product
#
#  def after_create(product); expire_cache_for(product); end
#  def after_update(product); expire_cache_for(product); end
#  def after_destroy(product); expire_cache_for(product); end
#
#private
#  def expire_cache_for(product)
#    puts "Expire: #{product.inspect}"
#    hash = { :controller => :products, :action => :main, :id => product.id }
#    expire_page(hash)
#    expire_fragment(hash)
#  end
#end
#ActiveRecord::Base.observers << :product_sweeper

class ProductsController < ApplicationController
  before_filter :setup_context

  # Google sitemap
  def sitemap
    headers['Content-Type'] = 'text/xml; charset=utf-8'
    @links = Product.find(:all).collect do |product|
      { :loc => "http://www.mountainofpromos.com/products/#{product.web_id}",
        :lastmod => product.updated_at.iso8601 }
    end
    
    render :template => 'sitemaps/sitemap', :layout=>false
  end
  
  # RSS feed with Googleness
  def rss  
    @products = Product.find(:all,
                             :include => [:supplier, :categories, :product_images, { :decorations => :technique } ],
      :conditions => 'NOT(products.deleted) AND products.price_comp_cache IS NOT NULL',
      :order => 'products.id')

    properties = Property.find_by_sql([
      "SELECT DISTINCT properties.name, properties.value, variants.product_id FROM properties JOIN properties_variants ON properties.id = properties_variants.property_id "+
      "JOIN variants ON properties_variants.variant_id = variants.id WHERE variants.product_id IN (?)" +
      "ORDER BY variants.product_id", @products.collect { |p| p.id }])

    @products.each do |product|
      hash = {}
      while (prop = properties.first) and (prop.product_id.to_i == product.id)
        hash[prop.name] = (hash[prop.name] || []) + [prop.translate]
        properties.shift
      end
      product.instance_variable_set("@properties_get", hash)
    end

#    @expiration_date = Time.now.months_ago(-1).iso8601
    render :layout=>false
  end
  
  # THIS USES GET TO CHANGE SERVER STATE!!!
private
  def expire_category(id)
    category = Category.find_by_id(id)
    
    path_list = category.path_obj_list
    path_list.pop if category.children_count == 0 or !@product.categories.index(path_list.last)
    
    path = path_list.collect { |x| x.name }.join('/').tr(' ','_')
    action = { :controller => 'categories', :action => 'show', :path => path }
    
    expire_page action
    expire_fragment action
    
    action
  end

public
  def set_featured
    raise "Permission denied" unless @user
  
    @product = Product.find(params[:id])
    expire_category(@product.featured_id) if @product.featured_id
        
    @product.featured_id = Integer(params[:category])
    @product.featured_at = Time.now
    @product.save!
    
    action = { :action => 'show', :id => @product }
    
    if params[:category]
      action = expire_category(params[:category]) 
    
      if params[:category].to_i == Category.root.id
        action = { :controller => 'categories', :action => 'home' }
        expire_page action
        expire_fragment action
      end
    end
    
    redirect_to action
  end
  
#  def prices
#    id = params[:id]
#    @product = Product.find(id)
#    
#    # Prices
#    prices = PriceSetter.new(@product.id)
#      
#    @minimums = prices.minimums
#    @price_func = prices.price_func
#    
#    @decoration_price_groups = DecorationPriceGroup.find(:all,
#      :conditions => "supplier_id = #{@product.supplier.id} AND product_id = #{@product.id}",
#      :include => [:technique => :decorations])    
#  end
#  
#  def decorations
#    id = params[:id]
#    @product = Product.find(id)
#    
#    # Decorations
#    @decorations = @product.decorations.find(:all, :include => [:technique])
#    decorations = @decorations.find_all { |x| x.technique.name != 'None' }
#    
#    @techniques = decorations.collect { |dec| dec.technique }.uniq.sort
#    @locations = decorations.collect { |dec| dec.location }.uniq
#
#    @decoration_hash = decorations.inject({}) do |hash, dec|
#      hash[[dec.location, dec.technique]] = dec
#      hash
#    end
#  end

  # Expects @category
  def list_sub
    @columns = 5
  
    @context = { :sort => 'name', :children => true }
    [:sort, :tag, :children].each { |n| @context[n] = params[n] if params[n] }

    raise ::ActionController::RoutingError, "Sort order must be #{Category.order_list.join(', ')}" unless Category.valid_order?(@context[:sort])

    options = @context.merge({
      :limit => @columns,
      :offset => params[:offset]
    })
      
    if options[:offset]
      @products = @category.find_products(options)
    else
      @products = @category.find_products_in_window(@product, options)
      @link_context = nil unless @products # Remove link context if invalid product window
    end
  end

  def show
    id = params[:id] && params[:id].split('-').first
    @product = Product.find(id)

    web_id = @product.web_id
    if @robot and (params[:category] || params[:id] != web_id)
      redirect_to({ :id => web_id })
      return
    end
    
    if (RAILS_ENV != "production") or @user or
       stale?(:last_modified => @product.updated_at.utc, :etag => @product)
     
      @categories = @product.categories.collect { |cat| Category.find_by_id(cat.id) }

      if params[:category]
        @category = Category.find_by_id(params[:category].to_i)
      else
        @category = @categories.first unless @category
      end

      if @link_context
        if @category
          list_sub
        else
          @link_context = false
        end
      end
      
      if @order
        OrderTask
        order = Order.find(session[:order_id])
        if order.task_completed?(AcknowledgeOrderTask)
          @message = "The current order is in production and can't be changed.  If you add this product a new order will be created."
        elsif order.task_completed?(RevisedOrderTask)
          @message = "Current order is ready for final acknowledgement.  If you another product the whole order will need to be reviewed again by Mountain Xpress Promotions."
        end
      end
  
      @title = "#{@product.name}, Custom Imprinted (#{@product.supplier.name}: #{@product.supplier_num})"
      
      @javascripts = ['effects', 'products']
      @javascripts += ['controls', 'rails'] if @user
      
      @email_subject = "#{@product.name} (M#{@product.id})"
    
      @description = "#{@product.name} from #{@product.price_min_cache} to #{@product.price_max_cache}."
#      @description += "Availible in " + @properties.collect do |name, values|
#        next nil if values.first.is_image?
#        name + ': ' + values.collect { |prop| prop.translate }.join(', ')
#      end.compact.join('; ') + '.  ' unless @properties.empty?
#      @description += "Customize with #{@techniques.collect { |t| t.name }.join(', ')}"  
    
      @keywords = "Custom Imprinted #{@product.name} #{@product.supplier.name} #{@product.supplier_num}"
      
      if @user
        @page_products = [] #PageProduct.find_all_by_product_id(@product.id, :include => [:page => :site])

        @sessions = SessionAccess.find(:all, :include => [:pages], :limit => 20,
                                       :conditions => "user_id IS NULL AND " +
                                       "access.page_accesses.controller = 'products' AND " +
                                       "access.page_accesses.action = 'show' AND " +
                                       "access.page_accesses.action_id = #{@product.id} AND " +
                                       "access.page_accesses.created_at > NOW() - '3 month'::interval",
                                       :order => "access.page_accesses.id DESC")

        @customers = Customer.find(:all, :include => { :orders => :items}, :limit => 20,
                             :conditions => "customers.person_name != '' AND " +
                             "order_items.product_id = #{@product.id}")
      end
      
      render :layout => 'simple' if params[:layout] == 'false'
    end
  end

end
