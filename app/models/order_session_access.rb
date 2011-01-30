class OrderSessionAccess < ActiveRecord::Base
  establish_connection("access")

  belongs_to :session, :class_name => 'SessionAccess', :foreign_key => 'session_access_id'
end
