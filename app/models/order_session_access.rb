class OrderSessionAccess < ActiveRecord::Base
  set_table_name 'access.order_session_accesses'

  belongs_to :session, :class_name => 'SessionAccess', :foreign_key => 'session_access_id'
end
