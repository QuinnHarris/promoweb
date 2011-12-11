class PageAccess < ActiveRecord::Base
  set_table_name 'access.page_accesses'

  belongs_to :session, :class_name => 'SessionAccess', :foreign_key => 'session_access_id'
  serialize :params

  belongs_to :product, :foreign_key => 'action_id'

  def uri
    hash = { :controller => controller[0] == '/'[0] ? controller : "/#{controller}", :action => action }
    hash[:id] = action_id if action_id
    hash.merge(params || {})
  end
end
