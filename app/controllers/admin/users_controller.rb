class Admin::UsersController < Admin::BaseController
#  before_filter :login_required

  def protect?(action)
    not %(login auth).include?(action)
  end

  def filter_parameters(unfiltered_parameters)
    parameters = unfiltered_parameters.dup
    if unfiltered_parameters['action'] == 'auth'
      parameters.delete('user_password')
    end
    parameters
  end

  def login
#    if request.host_with_port == "www.mountainofpromos.com"
#      redirect_to :host => "app.mountainofpromos.com" 
#      return
#    end

    if session[:user_id]
      redirect_to admin_orders_path
      return
    end
  end

  def auth
    if user = User.authenticate(params[:user][:login], params[:user][:password])
      session[:user_id] = user.id

      # Update Session
      if Rails.env.production?
        session_record = SessionAccess.find(session[:ses_id])
        logger.info("Replacing session user ID: #{session_record.user_id} => #{user.id}") if session_record.user_id
        session_record.user_id = user.id
        session_record.save!
      end
      
      flash['notice']  = "Login successful"
      redirect_back_or_default admin_orders_path
    else
      flash.now['notice']  = "Login unsuccessful"
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

  def new
    @this_user = User.new
  end

  def create
    @this_user = UserPass.new(params[:user])
    
    if @this_user.save
      User.authenticate(@this_user.login, params[:user][:password])
      flash['notice']  = "Signup successful"
      redirect_back_or_default :controller => :orders, :action => :index
    else
      redirect_to :action => :index
    end
  end
  
  def edit
    if params[:user] and params[:user][:password].empty?
      @this_user = User.find(params[:id])
      params[:user].delete(:password_confirmation)
    else
      @this_user = User.find(params[:id])
    end
    
    if params[:user]
      params[:user][:email] = nil if params[:user][:email].blank?
      if @this_user.update_attributes(params[:user])
        redirect_to :action => :index
        return
      end
    end
    
    @this_user.password = nil
  end

  def update
    if params[:user][:email].blank?
      @this_user = User.find(params[:id])
      params[:user][:email] = nil 
    else
      @this_user = UserPass.find(params[:id])
    end

    if @this_user.update_attributes(params[:user])
      redirect_to :back
    else
      render :action => 'edit'
    end
  end
  
  def show

  end

  def password
    @this_user = UserPass.find(session[:user_id])
    
    if request.post?
      if User.authenticate(@this_user.login, params[:user].delete(:old_password))
        if @this_user.update_attributes(params[:user])
          redirect_to :controller => :orders, :action => :index
          return
        end
      else
        @this_user.errors.add(:old_password, "incorrect")
      end
    end
    
    @this_user.password = nil
    @this_user.password_confirmation = nil
    class << @this_user; def old_password; end; end
  end
end
