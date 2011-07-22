class Admin::PhoneController < Admin::BaseController
  def access
    calls = CallLog.find(:all, :order => 'id DESC', :conditions => { :inbound => true }, :order => 'id DESC', :limit => 4)
    
    @calls = calls.collect do |call_log|
      customer = Customer.find(:first,
                               :include => :phone_numbers,
                               :conditions => { 'phone_numbers.number' => call_log.caller_number.gsub(/^1/,'').to_i } )

      next [call_log, customer] if customer

      /^1?(\d{3})/ === call_log.caller_number
      prefix = $1
      access = PageAccess.find(:all,
                              :include => :session,
                              :limit => 10,
                              :order => 'page_accesses.id DESC',
                              :conditions => ["page_accesses.created_at > ? AND session_accesses.area_code = ? AND page_accesses.controller = 'products' AND action = 'main'", Time.now - 30.days, prefix])

      [call_log, access]
    end
    
  end

  def calls
    @calls = CallLog.find(:all, :order => 'id DESC', :limit => 100)
  end

  def setup
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
