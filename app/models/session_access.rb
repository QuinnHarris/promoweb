class SessionAccess < ActiveRecord::Base
  establish_connection("access")

  has_many :pages, :class_name => 'PageAccess', :foreign_key => 'session_access_id', :order => 'id'
  has_many :orders, :class_name => 'OrderSessionAccess', :foreign_key => 'session_access_id'
end
