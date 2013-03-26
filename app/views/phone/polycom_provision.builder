xml.instruct! :xml, :version=> '1.0', :standalone => 'yes'
xml.userinfo do
  idx = 1
  xml.attendant( 'attendant.reg' => 1 ) do
    xml.tag!('attendant.resourceList',
      @users.each_with_object({}) do |user, hash|
        hash.merge!("attendant.resourceList.#{idx}.address" => user.login,
	           "attendant.resourceList.#{idx}.label" => "#{user.login.capitalize} #{user.extension}",
		   "attendant.resourceList.#{idx}.proceedingIsRecipient" => '0',
		   "attendant.resourceList.#{idx}.proceedingIsRecipient" => 'normal')
        idx += 1
      end)
  end

  xml.reg( 'reg.1.displayName' => @user.name,
  	   'reg.1.address' => @user.login,
	   'reg.1.label' => "#{@user.login.capitalize} #{@user.extension}",
	   'reg.1.auth.userId' => @user.login,
	   'reg.1.auth.password' => @user.phone_password,
	   'reg.1.lineKeys' => [5-idx, 1].max,
	   'reg.1.lineKeys.SPIP650' => [7-idx, 1].max,
	   'reg.1.lineKeys.SPIP670' => [7-idx, 1].max )

  xml.mb do
    xml.main( 'mb.main.home' => "http://www.mountainofpromos.com/phone/polycom/#{@user.login}" )
    xml.idleDisplay( 'mb.idleDisplay.home' => "http://www.mountainofpromos.com/phone/polycom_idle/#{@user.login}" )
  end

  xml.TCP_IP do
    xml.SNTP( 'tcpIpApp.sntp.gmtOffset' => -25200,
    	      'tcpIpApp.sntp.daylightSavings.enable' => '1' )
  end
end
