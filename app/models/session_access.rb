class SessionAccess < ActiveRecord::Base
  set_table_name 'access.session_accesses'

  has_many :pages, :class_name => 'PageAccess', :foreign_key => 'session_access_id', :order => 'id'
  has_many :orders, :class_name => 'OrderSessionAccess', :foreign_key => 'session_access_id'
end
