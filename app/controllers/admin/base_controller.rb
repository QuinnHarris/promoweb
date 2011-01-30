class Admin::BaseController < ApplicationController
  before_filter :login_required  
  #session :session_secure => true
end
