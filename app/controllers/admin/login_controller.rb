class Admin::LoginController < ApplicationController
  User
  
  before_filter :login_required
  def protect?(action)
    return false if action == 'auth'
    true
  end

  def filter_parameters(unfiltered_parameters)
    parameters = unfiltered_parameters.dup
    if unfiltered_parameters['action'] == 'auth'
      parameters.delete('user_password')
    end
    parameters
  end

  def auth
#    if request.host_with_port == "www.mountainofpromos.com"
#      redirect_to :host => "app.mountainofpromos.com" 
#      return
#    end
  
    if session[:user_id]
      redirect_to :controller => :orders, :action => :index
      return
    end
  
    if request.post?
      if user = User.authenticate(params[:user_login], params[:user_password])
        session[:user_id] = user.id

        # Update Session
        if RAILS_ENV == "production"
          session_record = SessionAccess.find(session[:ses_id])
          logger.info("Replacing session user ID: #{session_record.user_id} => #{user.id}") if session_record.user_id
          session_record.user_id = user.id
          session_record.save!
        end

        flash['notice']  = "Login successful"
        redirect_back_or_default :controller => :orders, :action => :index
      else
        flash.now['notice']  = "Login unsuccessful"
      end
    end
  end
  
  def logout
    session[:user_id] = nil
    redirect_back_or_default '/'
  end
  
  
  def index
    @title = "Users"
    @users = User.find(:all, :order => 'id')
    @users -= [@users.find { |u| u.id == 0 }]  # Remove System user
  end

  def add
    @user = UserPass.new(params[:user])

    if request.post? and @user.save
      User.authenticate(@user.login, params[:user][:password])
      flash['notice']  = "Signup successful"
      redirect_back_or_default :controller => :orders, :action => :index
    end

    render :action => :user
  end
  
  def edit
    if params[:user] and params[:user][:password].empty?
      @user = User.find(params[:id])
      params[:user].delete(:password_confirmation)
    else
      @user = UserPass.find(params[:id])
    end
    
    if params[:user]
      params[:user][:email] = nil if params[:user][:email].blank?
      if @user.update_attributes(params[:user])
        redirect_to :action => :index
        return
      end
    end
    
    @user.password = nil
    render :action => :user
  end
  
  def password
    @user = UserPass.find(session[:user_id])
    
    if request.post?
      if User.authenticate(@user.login, params[:user].delete(:old_password))
        if @user.update_attributes(params[:user])
          redirect_to :controller => :orders, :action => :index
          return
        end
      else
        @user.errors.add(:old_password, "incorrect")
      end
    end
    
    @user.password = nil
    @user.password_confirmation = nil
    class << @user; def old_password; end; end
  end

  def other

  end

  Phone
  def phones
    @user = UserPass.find(params[:id]) if params[:id] and @permissions.include?('Super')
  end

  def phone
    @user = UserPass.find(params[:user_id]) if params[:user_id] and @permissions.include?('Super')
    if params[:type]
      klass = Kernel.const_get(params[:type])
      @phone = klass.new(:user => @user)
      raise "Improper type: #{klass.inspect}" unless @phone.is_a?(Phone)
    elsif params[:id]
      @phone = Phone.find(params[:id])
    end

    if params[:phone]
      @phone.attributes = params[:phone]
      return unless @phone.valid?
      @phone.save!
      if @phone.is_a?(CustSIPPhone)
        redirect_to :id => @phone.id
      else
        redirect_to :action => :phones
      end
    end
  end

  def phone_remove
    Phone.find(params[:id]).destroy
    redirect_to :action => :phones
  end
end
