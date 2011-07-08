xml.document( :type => 'freeswitch/xml' ) do
  xml.section( :name => 'directory' ) do
    xml.domain( :name => 'mountainofpromos.com' ) do
      xml.groups do
        unless @no_external
          xml.group( :name => "external" ) do
            xml.users do
              for user in @users.find_all { |u| u.direct_phone_number }
                xml.user( :id => user.direct_phone_number) do
	          xml.params do
   	            xml.param( :name => 'extension', :value => user.extension )
       	            xml.param( :name => 'vm-enabled', :value => 'false' )
  	          end
    	          xml.variables do
	            xml.variable( :name => 'user_context', :value => 'public' )
  	          end
		end
	      end
	    end
          end
	end
	unless @no_internal
          xml.group( :name => "internal" ) do
            xml.users do
	      xml.user( :id => 'sales', 'number-alias' => '100' ) do
		xml.params do
		  xml.param( :name => 'vm-password', :value => '0000' )
		  xml.param( :name => 'vm-mailto', :value => 'sales@mountainofpromos.com' )
 		  xml.param( :name => 'vm-email-all-messages', :value => 'true' )
		  xml.param( :name => 'vm-attach-file', :value => 'true' )
		end
	      end
              for user in @users
	        xml.user( :id => user.login, 'number-alias' => user.extension ) do
		  xml.params do
	  	    dial = "{presence_id=${dialed_user}@${dialed_domain},effective_caller_id_number=#{user.phone_i}}${sofia_contact(${dialed_user}@${dialed_domain})}"
		    external = (user.external_phone_enable ? ",[leg_timeout=#{user.external_phone_timeout}]sofia/gateway/voipstreet/1#{user.external_phone_number}" : '')
    		    xml.param( :name => 'dial-string', :value => dial + (user.external_phone_all ? external : '') )
    		    xml.param( :name => 'dial-string-external', :value => external ) if user.external_phone_enable and !user.external_phone_all
		    xml.param( :name => 'password', :value => user.phone_password )
		    xml.param( :name => 'vm-password', :value => '0000' )
		    xml.param( :name => 'vm-mailto', :value => user.email )
		    xml.param( :name => 'vm-email-all-messages', :value => 'true' )
		    xml.param( :name => 'vm-attach-file', :value => 'true' )
		    xml.param( :name => 'http-allowed-api', :value => 'voicemail' )
		  end
		  xml.variables do
		    xml.variable( :name => 'toll_allow', :value => 'domestic,international,local' )
		    xml.variable( :name => 'accountcode', :value => user.login )
		    xml.variable( :name => 'user_context', :value => 'default' )
 		    xml.variable( :name => 'effective_caller_id_name', :value => user.name )
		    xml.variable( :name => 'effective_caller_id_number', :value => user.extension )
		    xml.variable( :name => 'outbound_caller_id_name', :value => "MTNPRO #{user.name.split(' ').first}"[0...15] )
		    xml.variable( :name => 'outbound_caller_id_number', :value => user.phone_i )
		    xml.variable( :name => 'dial_out_prefix', :value => user.external_phone_number ? user.external_phone_number.to_s[0..2] : '970' )
		  end
		end
	      end
            end
          end

          xml.group( :name => 'active' ) do
            xml.users do
  	      for user in @active
	        xml.user( :id => user.login, :type => 'pointer' )
	      end
            end
	  end
	end
      end
    end
  end
end