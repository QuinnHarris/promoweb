require 'sites'

require 'spider'

# Customer robots parse
require 'robot_rules'


site_records = Site.find(:all)
new_classes = ObjectSpace.subclasses_of(Site) - site_records.collect { |r| r.class }
new_classes.each do |klass|
  site_rec = klass.create
  site_rec.pages.create(:request_uri => '')
  site_records << site_rec
  puts "Added #{klass} for #{klass.url}"
end

$sites = {}
site_records.each do |site_record|
  $sites[site_record.url] = site_record
end

#$sites.delete('www.rushimprint.com')  # Not competative
$sites.delete('www.promopeddler.com') # Too many pages
$sites.delete('www.pinnaclepromotions.com') # Crash


# DB Include Check
class IncludedInDB
  def initialize
  end

  def <<(uri)
    unless site_record = $sites[uri.host]
#      puts "Unknown Site: #{uri}"
      return
    end
    
    request_uri = uri.request_uri.gsub(/^\/+/,'')
    unless page_record = site_record.pages.find_by_request_uri(request_uri)
      puts "Unknown Page: #{uri}"
      page_record = site_record.pages.create(:request_uri => request_uri)
    end
    
    page_record.fetch_complete_at = Time.now
    page_record.save!
  end

  def include?(uri)
    return false unless site_record = $sites[uri.host]
    request_uri = uri.request_uri.gsub(/^\/+/,'')
    site_record.pages.find_by_request_uri(request_uri, :conditions => "NOT NULLVALUE(fetch_complete_at) AND fetch_complete_at > fetch_started_at")
  end
end

class NextUrlsInDB
  def initialize
  end
  
  def pop
    now = Time.now
    page_record = nil
    zero_time = Time.at(1)
    until page_record
      site = $sites.values.find { |t| t.hit_at.nil? }
      site = $sites.values.find_all { |t| !t.hit_at.nil? }.sort { |l,r| l.hit_at <=> r.hit_at }.first unless site
      site.hit_at = now
      site.save!
      
      puts "Site: #{site.class}"
      
      order = "pages.fetch_started_at NULLS FIRST, pages.fetch_complete_at NULLS FIRST"
      order += site.sql_order ? ", #{site.sql_order}" : ''
      page_record = site.pages.find(:first,
        :order => order)
    end

    page_record.fetch_started_at = now
    page_record.save!

    { page_record => [page_record.url]}
  end
  
  def empty?; false; end
  
  def push(a_msg)
    return unless a_msg
    a_msg.each do |key, value|
      uri = URI.parse(value)
      unless site_record = $sites[uri.host]
#        puts "Unknown Site: #{uri}"
        return
      end
      begin
        request_uri = uri.request_uri.gsub(/^\/+/,'')
      rescue
        raise "Value: #{value}"
      end
      
      orig_uri = request_uri.dup
      
      return if /[^\/]+\/[^\?]*\.(jpeg|jpg|png|gif|exe|css|pdf)(\?.*)?$/i =~ request_uri
      return unless site_record.include_uri?(request_uri)
      request_uri = site_record.normalize_uri(request_uri)
      
      return if site_record.pages.find_by_request_uri(request_uri)
      puts " * #{orig_uri} => #{request_uri}"
      site_record.pages.create(:request_uri => request_uri)
    end
  end  
end

class MySpiderInstance < SpiderInstance
  @@cache_obj = FileCache.new('spider')
  
  def get_page(parsed_url, &block)
    @seen << parsed_url
    begin
      r = @@cache_obj.cache(parsed_url) do
        http = Net::HTTP.new(parsed_url.host, parsed_url.port)
        http.use_ssl = parsed_url.scheme == 'https'
        # Uses start because http.finish cannot be called.
        http.start {|h| h.request(Net::HTTP::Get.new(parsed_url.request_uri,
                                                 @headers))}
      end

      if r.redirect?
        get_page(URI.parse(construct_complete_url(parsed_url,r['Location'])), &block)
      else
        block.call(r)
      end
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::ETIMEDOUT, EOFError, URI::InvalidURIError => e
      p e
      nil
    end
  end
end


a_spider = MySpiderInstance.new(nil, IncludedInDB.new)
a_spider.store_next_urls_with NextUrlsInDB.new
a_spider.add_url_check { |a_url| not a_url =~ /\/\/[^\/]+\/[^\?]*\.(jpeg|jpg|png|gif|exe|css|pdf)(\?.*)?$/i }
a_spider.add_url_check { |a_url| not a_url.index("https") }
a_spider.add_url_check do |a_url|
  uri = URI.parse(a_url)
  return nil unless site_record = $sites[uri.host]
  site_record.include_uri?(uri.request_uri)
end
a_spider.setup do |a_url|
  puts "Fetching: #{a_url}"
end
a_spider.on :success do |a_url, resp, page_record|
  puts " Success: #{a_url}"
end
a_spider.start!
