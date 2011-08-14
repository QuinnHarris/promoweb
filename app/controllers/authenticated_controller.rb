class AuthenticatedController < ApplicationController
  before_filter :setup_user
  def setup_user
    unless request.protocol == "https://" or RAILS_ENV != "production"
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

      if @order and @user.current_order_id != @order.id
        User.update_all("current_order_id = #{@order.id}", "id = #{@user.id}")
      end
    else
      @permissions = %w(Customer)
    end
  end
end
