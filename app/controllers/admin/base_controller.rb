class Admin::BaseController < AuthenticatedController
  before_filter :login_required  
  #session :session_secure => true

  self.stylesheets << 'orders'
end
