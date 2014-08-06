class Fail2banNotifier
  def initialize(options)
    @default_options = options
    @default_options[:logfile] ||= Rails.root.join('log', 'fail2ban.log')

    # Roll over every 30M, keep 10 files
    @logger ||= Logger.new(@default_options[:logfile], 10, 30*1024*1024)
  end

  def call(exception, options={})
    env = options[:env]
    request = ActionDispatch::Request.new(env)

    # <ip> : <exception class> : <method> <path> -- <params>
    msg = "%s : %s : %s %s -- %s" % [
      request.remote_ip,
      exception.class,
      request.request_method,
      env["PATH_INFO"],
      request.filtered_parameters.inspect
    ]
    @logger.error(msg)
  end
end