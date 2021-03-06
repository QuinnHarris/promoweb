xml.instruct! :xml, :version=> '1.0', :standalone => 'yes'
xml.userinfo do
  xml.reg( 'reg.1.displayName' => @user.name,
  	   'reg.1.address' => @user.login,
	   'reg.1.label' => @user.extension,
	   'reg.1.auth.userId' => @user.login,
	   'reg.1.auth.password' => @user.phone_password,
	   'reg.1.lineKeys' => 3 )

  xml.microbrowser do
    xml.main( 'mb.main.home' => "http://www.mountainofpromos.com/phone/polycom/#{@user.login}" )
    xml.idleDisplay( 'mb.idleDisplay.home' => "http://www.mountainofpromos.com/phone/polycom_idle/#{@user.login}" )
  end

  xml.TCP_IP do
    xml.SNTP( 'tcpIpApp.sntp.gmtOffset' => -25200,
    	      'tcpIpApp.sntp.daylightSavings.enable' => '1' )
  end
end
