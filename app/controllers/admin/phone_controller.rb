class Admin::PhoneController < Admin::BaseController
  def edit
    @user = User.find(params[:id]) if params[:id] and @permissions.include?('Super')

    if params[:phone]
      @phone = @user.phones.new(params[:phone])
      return unless @phone.valid?
      @phone.save!
    elsif params[:user]
      @user.attributes = params[:user]
      return unless @user.valid?
      @user.save!
    end
  end

  def phone_add
    @user = User.find(params[:user_id]) if params[:user_id] and @permissions.include?('Super')
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
    redirect_to :action => :phones, :id => params[:user_id]
  end
end
