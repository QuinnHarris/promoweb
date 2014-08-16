class Admin::PhonesController < Admin::BaseController
  def index
    if permission?('Super')
      @user = User.find(params[:user_id])
    else
      raise "Permission Denied" unless params[:user_id] == @user.id
    end

    @phone = Phone.new

    if params[:phone]
      @phone = @user.phones.new(params[:phone])
      return unless @phone.valid?
      @phone.save!
    elsif params[:user]
      @user.attributes = params[:user]
      return unless @user.valid?
      @user.save!
    end

    @registrations = [] #Registration.where(:reg_user => @user.login).all || []
  end

  def create
    if permission?('Super')
      @user = User.find(params[:user_id])
    else
      raise "Permission Denied" unless params[:user_id] == @user.id
    end

    @phone = Phone.new(params[:phone].merge(:user_id => @user.id))
    if @phone.save
      redirect_to :action => 'index'
    else
      @registrations = Registration.where(:reg_user => @user.login).all || []

      render :action => :index
    end
  end

  def destroy
    Phone.find(params[:id]).destroy
    redirect_to :action => :index
  end
end
