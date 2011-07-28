module Admin::AccessHelper
  def parse_url(arg)
    return nil if arg.nil?
    URI::split(arg.gsub(' ','%20'))[2] 
  end

  def get_urls_host(ref)
    return nil unless host = parse_url(ref)
    return nil if host == SITE_NAME
    host
  end

  def get_params_url(arg)
    return nil if arg.nil?
    URI::split(arg.gsub(' ','%20'))[7] 
  end

  def referer_tag(referer)
    searchterms = ''
    site = nil
    actual_referer = referer

    begin
      domain = get_urls_host(referer)
            
      uripars = get_params_url(referer) unless referer.nil?
      params = CGI.parse(uripars) if uripars and not(uripars.nil?)

      case domain
      when /google\./i
        # Googles search terms are in "q"
        searchterms = params['q']
        actual_referer = referer.gsub("/url?","/search?")
        site = 'google'
      when /bing\./i
        searchterms = params['q']
        site = 'bing'
      when /alltheweb\./i
        # All the Web search terms are in "q"
        searchterms = params['q']
        site = 'alltheweb'
      when /yahoo\./i
        searchterms = params['p']
        site = 'yahoo'
      when /search\.aol\./i
        # Yahoo search terms are in "query"
        searchterms = params['query']
        site = 'aol'
      when /search\.msn\./i
        # MSN search terms are in "q"
        searchterms = params['q']
        site = 'msn'
      when /thefind\./i
        referer =~ /thefind\.com\/(.*)$/i
        searchterms = [$1]
        site = 'thefind'
      end
    rescue Exception=>ex
      #      RAILS_DEFAULT_LOGGER.debug("#{ex} - #{ex.backtrace.join("\n\t")}")
    end

    if site
      link_to "#{site.capitalize}: #{searchterms.first}", actual_referer
    else
      referer
    end
  end
end
