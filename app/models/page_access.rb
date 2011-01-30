class PageAccess < ActiveRecord::Base
  establish_connection("access")

  belongs_to :session, :class_name => 'SessionAccess', :foreign_key => 'session_access_id'
  serialize :params

  def uri
    hash = { :controller => controller[0] == '/'[0] ? controller : "/#{controller}", :action => action }
    hash[:id] = action_id if action_id
    hash.merge(params || {})
  end
end
