class AuthenticatedController < ApplicationController
  self.stylesheets << 'orders'
  
  before_filter :setup_user
  def setup_user
    unless request.protocol == "https://" or Rails.env.development?
      redirect_to :protocol => "https://" 
      return false
    end

    # Set @permissions and @user if applicable for all controllers
    if session[:user_id]
      @user = User.find(session[:user_id])

      @permissions = @user.permissions.find(:all,
        :conditions => ['order_id IS NULL OR order_id = ?',
        @order && @order.id]).collect { |p| p.name }
      #raise "Permission Denied" if @permissions.empty?
      @customer_zone = Time.zone if session[:tz]
      Time.zone = 'Mountain Time (US & Canada)'
    else
      @permissions = %w(Customer)
    end
  end
end
