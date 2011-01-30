# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
# 
require_dependency "login_system"

class ApplicationController < ActionController::Base
  include ExceptionNotification::Notifiable
  include LoginSystem
  
public
  def self.caches_page(*actions)
    return unless perform_caching
    actions.each do |action|
      class_eval "after_filter { |c| c.cache_page if c.action_name == '#{action}' and !c.session[:user] and @real_user }"
    end
  end
  
  layout 'global'
  
  @@robot_str = %w(bot spider crawler wget getright libwww-perl lwp- yahoo google java jdk altavista scooter lycos infoseek lecodechecker slurp twiceler ia_archiver siteuptime yanga jeeves bing)
  
  before_filter :set_link_context
  def set_link_context
#    Category.reload  # Kludgy shit!!!
    user_agent = request.env['HTTP_USER_AGENT'] ? request.env['HTTP_USER_AGENT'].downcase : 'unknown'
    @robot = @@robot_str.find { |str| user_agent.index(str) }
    @robot = true if /^65\.55/ =~ request.remote_ip # Microsoft bot that doesn't claim to be a bot
    @link_context = (((user_agent.index('mozilla') or user_agent.index('opera'))) and !@robot)
    @real_user = @link_context
    @real_user = true if user_agent.include?('blackberry')

    # Track access
    if (RAILS_ENV == "production") and @real_user
      unless session[:ses_id]
        session_record = SessionAccess.find(:first, :conditions => 
          ["user_agent = ? AND id IN (SELECT session_access_id FROM page_accesses WHERE address = ? AND created_at > NOW() - '3 month'::interval )",
           request.env['HTTP_USER_AGENT'], request.remote_ip])
        session_record = SessionAccess.create(
          :user_agent => request.env['HTTP_USER_AGENT'],
          :language => request.env['HTTP_ACCEPT_LANGUAGE'] && request.env['HTTP_ACCEPT_LANGUAGE'].to(63)) unless session_record
        session[:ses_id] = session_record.id
      end

      # Lifted from log_processing_for_parameters in actionpack-2.2.2/lib/action_controller/base.rb
      parameters = respond_to?(:filter_parameters) ? filter_parameters(params) : params.dup
      access_attributes = { 
        :session_access_id => session[:ses_id],
        :address => request.remote_ip,
        :secure => (request.protocol == "https://"),

        :controller => parameters.delete(:controller),
        :action => parameters.delete(:action) }

      unless request.referer.blank?
        our_prefix = request.protocol + request.host
        unless request.referer[0...our_prefix.length] == our_prefix
          access_attributes[:referer] = request.referer
        end
      end

      if parameters[:id]
        id_prefix = parameters[:id].split(/-|\&|\?/).first
        id_num = id_prefix.to_i.to_s
        if id_num.to_s == id_prefix
          parameters.delete(:id) if id_num.to_s == parameters[:id]
          access_attributes[:action_id] = id_num
        end
      end

      parameters.delete(:artwork) # Kludge to remove artwork upload info

      access_attributes[:params] = parameters.empty? ? nil : parameters.to_hash
      PageAccess.create(access_attributes)
    end
    
    # Set @order for all controllers
    if params[:auth] or params[:order_id] or session[:order_id]      
      if params[:auth]
        customer = Customer.find_by_uuid(params[:auth])
        if params[:order_id]
          @order = customer.orders.find_by_id(params[:order_id])
          raise "Can't find order for customer" unless @order        
        else
          @order = customer.orders.first
        end
      else
        @order = Order.find(params[:order_id] || session[:order_id], :include => [:customer, :user])
        if params[:order_id] and !session[:user_id]
          # If Customer (or not logged in)
          if session[:order_id]
            # If changing order
            old_order = Order.find(session[:order_id])
            if old_order.customer_id != @order.customer_id
              @order = nil
              raise "Order #{session[:order_id]} does not belong to current customer"
            end
          else
            # If not logged in and not establised as customer
            if params[:controller].include?('admin')
              redirect_to :controller => '/admin', :action => ''
            else
              raise "Can't set order unless logged in or a customer order"
            end            
          end
        end
      end

      session[:tz] = nil if params[:order_id] and session[:order_id] != params[:order_id]
      if !session[:tz] and @order.customer.default_address and @order.customer.default_address.postalcode
        list = Zipcode.find_by_sql(["SELECT z.*, r.name as state "+
                                    "FROM zipcodes z, regions r " +
                                    "WHERE z.region = r.id AND z.country = 229 AND z.zip = ?",
                                    @order.customer.default_address.postalcode[0..4]])
        if list.length == 1
          session[:tz] = list.first.tz_name
          Time.zone = session[:tz] || 'Mountain Time (US & Canada)'
        end
      end
      
      session[:order_id] = @order && @order.id
      raise "Unknown Order" unless session[:order_id]
    end

    # Set @permissions and @user if applicable for all controllers
    if session[:user_id]
      @user = User.find(session[:user_id])

      @permissions = @user.permissions.find(:all,
        :conditions => ['order_id IS NULL OR order_id = ?',
        session[:order_id]]).collect { |p| p.name }
      #raise "Permission Denied" if @permissions.empty?
      @customer_zone = Time.zone if session[:tz]
      Time.zone = 'Mountain Time (US & Canada)'

      if @order and @user.current_order_id != @order.id
        User.update_all("current_order_id = #{@order.id}", "id = #{@user.id}")
      end
    else
      @permissions = %w(Customer)
    end
    
    true
  end

end
