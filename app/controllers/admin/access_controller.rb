class Admin::AccessController < Admin::BaseController
  @@domain_icons = {
    'www.google.com' => 'google',
    'search.yahoo.com' => 'yahoo',
    'search.live.com' => 'live'
  }
  cattr_reader :domain_icons

  def paths
    @title = "Access Paths"
    conditions = ["user_id IS NULL"]

    if params[:session_id]
      conditions << "session_accesses.id = #{params[:session_id].to_i}"
    else
      conditions << "access.page_accesses.created_at > (NOW() - '2 days'::interval)"
      conditions << "access.session_accesses.id IN (SELECT session_access_id FROM access.page_accesses WHERE created_at > NOW() - '1 day'::interval)"
    end

    if params[:ppc]
      conditions << "access.session_accesses.id IN (SELECT session_access_id FROM access.page_accesses WHERE created_at > NOW() - '1 day'::interval AND params ~ 'gclid')"
    end

    logger.info("Conditions: #{conditions.collect { |s| "(#{s})" }.join(' AND ').inspect}")

    @sessions = SessionAccess.find(:all, :include => [:pages, :orders], :limit => 500,
                                   :conditions => conditions.collect { |s| "(#{s})" }.join(' AND '),
                                   :order => 'access.session_accesses.id DESC, access.page_accesses.id DESC')
  end

  def entries
    @tasks = FirstPaymentOrderTask.find(:all, :order => 'order_id')

    @entries = PageAccess.find_by_sql(
      ["SELECT order_session_accesses.order_id, page_accesses.created_at, page_accesses.params LIKE '%gclid%' AS ppc, page_accesses.referer FROM " +
            "(SELECT session_access_id, referer, min(id) AS id FROM access.page_accesses WHERE NOT nullvalue(referer) GROUP BY session_access_id, referer) AS page_refers " +
            "JOIN page_accesses ON page_refers.id = page_accesses.id " +
            "JOIN session_accesses ON page_refers.session_access_id = session_accesses.id " +
            "JOIN order_session_accesses ON page_refers.session_access_id = order_session_accesses.session_access_id " +
            "WHERE nullvalue(session_accesses.user_id) AND order_session_accesses.order_id IN (?) " +
            "ORDER BY order_session_accesses.order_id, page_accesses.created_at",
       @tasks.collect { |t| t.order_id }])
  end


  # Phone
  def calls
    @calls = CallLog.find(:all, :order => 'id DESC', :limit => 100)
  end

  def inbound
    calls = CallLog.find(:all, :order => 'id DESC', :conditions => { :inbound => true }, :order => 'id DESC', :limit => 4)
    
    @calls = calls.collect do |call_log|
      customer = Customer.find(:first,
                               :include => :phone_numbers,
                               :conditions => { 'phone_numbers.number' => call_log.caller_number.gsub(/^1/,'').to_i } )

      next [call_log, customer] if customer

      /^1?(\d{3})/ === call_log.caller_number
      prefix = $1
      access = PageAccess.find(:all,
                              :include => :session,
                              :limit => 10,
                              :order => 'page_accesses.id DESC',
                              :conditions => ["page_accesses.created_at > ? AND session_accesses.area_code = ? AND page_accesses.controller = 'products' AND action = 'main'", Time.now - 30.days, prefix])

      [call_log, access]
    end
    
  end
end
