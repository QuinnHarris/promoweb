require_dependency "login_system"

class ApplicationController < ActionController::Base
  # Disabled for now but fix (causes JS calls to not have session)
  #protect_from_forgery

  include LoginSystem
  
  class_attribute :stylesheets
  self.stylesheets = ['application']
  
public
  def self.caches_page(*actions)
    return unless perform_caching
    actions.each do |action|
      class_eval "after_filter { |c| c.cache_page if c.action_name == '#{action}' and !c.session[:user] and @real_user }"
    end
  end
  
  layout 'global'
  
  @@robot_str = %w(bot spider crawler wget getright libwww-perl lwp- yahoo google java jdk altavista scooter lycos infoseek lecodechecker slurp twiceler ia_archiver siteuptime yanga jeeves bing)
  
  before_filter :setup_link_context
  def setup_link_context
    Category.refresh  # Kludgy shit!!!
    user_agent = request.env['HTTP_USER_AGENT'] ? request.env['HTTP_USER_AGENT'].downcase : 'unknown'
    @robot = @@robot_str.find { |str| user_agent.index(str) }
    @robot = true if /^65\.55/ =~ request.remote_ip # Microsoft bot that doesn't claim to be a bot
    @link_context = (((user_agent.index('mozilla') or user_agent.index('opera'))) and !@robot)
    @real_user = @link_context
    @real_user = true if user_agent.include?('blackberry')

    # Track access
    if Rails.env.production? and @real_user
      unless session[:ses_id]
        session_record = SessionAccess.find(:first, :conditions => 
          ["user_agent = ? AND id IN (SELECT session_access_id FROM access.page_accesses WHERE address = ? AND created_at > NOW() - '3 month'::interval )",
           request.env['HTTP_USER_AGENT'], request.remote_ip])

        unless session_record
          attributes = {
            :user_agent => request.env['HTTP_USER_AGENT'],
            :language => request.env['HTTP_ACCEPT_LANGUAGE'] && request.env['HTTP_ACCEPT_LANGUAGE'].to(63)
          }

          # GeoIP area code for incoming phone lookup
          if gi = GEOIP.look_up(request.remote_ip)
            attributes.merge!(:area_code => gi[:area_code])
          end

          session_record = SessionAccess.create(attributes)
        end

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
    
    true
  end

  # before_filter :setup_context for non Authenticated controllers
  def setup_context
    # Set @order for all controllers
    @order = Order.find(session[:order_id]) unless @order or session[:order_id].nil?
    @user = User.find(session[:user_id]) unless @user or session[:user_id].nil?
  end

protected
  def permission?(name)
    @permissions.include?(name)
  end

end
