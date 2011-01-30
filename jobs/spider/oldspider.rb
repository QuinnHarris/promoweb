#require File.dirname(__FILE__) + '/../config/environment'
#require 'net/httpclient'

require 'generic_import'
require 'hpricot'

#%w(www.qualitylogoproducts.com www.4imprint.com www.branders.com www.epromos.com www.empirepromos.com www.promopeddler.com www.rushimprint.com www.gimmees.com www.gopromos.com).each do |name|
#  Site.create(:url => name).pages.create(:path => '')
#end
#%w(www.pinnaclepromotions.com www.superiorpromos.com www.inkhead.com www.promosontime.com www.getabag.com ecopromosonline.com www.motivators.com store.bagwarehouse.com).each do |name|
#  Site.create(:url => name).pages.create(:path => '')
#end

class Robotstxt
  def initialize(file_name)
    @disallow = []
    File.open(file_name) do |f|
      f.each do |line|
        all, key, value = /(.+):(.+)/.match(line)
        next unless key and value
        case key.strip.downcase
          when 'disallow'
            @disallow << value.strip
        end
      end
    end
  end
end

$robots_map = {}

Site.find(:all).each do |site|
  url = "http://#{site.url}/robots.txt"
  wf = WebFetch.new(url)
  path = wf.get_path
  robots_map[site.id] = Robotstxt.new(path)
end


Hpricot.buffer_size = 262144

while page_record = Page.find(:first, :include => :site, :conditions => "NULLVALUE(pages.downloaded_at) AND pages.invalid != true", :order => "sites.hit_at NULLS FIRST, pages.downloaded_at NULLS FIRST")
  url = "http://#{page_record.site.url}/#{page_record.path}"
  puts "Get: #{url}  Site Hit: #{page_record.site.hit_at ? (Time.now - page_record.site.hit_at) : 'FIRST'}"
  
#  Page.transaction do
  begin
    wf = WebFetch.new(url)
    path = wf.get_path
  rescue Timeout::Error
    puts "Timeout"
  rescue
    puts "other"
  end
  
  now = nil
  Page.transaction do
    if path
      begin
        doc = open(path) { |f| Hpricot(f) }
      rescue
      end
     
      if doc
        links = doc.search("//a").collect do |a_node|
          next unless href = a_node.attributes['href']
          next if href.index("https")
          next if href.index("#")

          all, site, path = /^(?:http\:\/\/([^\/]*))?([^:]*)$/.match(href.strip).to_a
          next unless all
          path.strip!
          next if /^[^\?]*\.(jpeg|jpg|png|gif|exe)(\?.*)?$/ =~ path
          if site and site.strip != page_record.site.url
            puts " *> #{all}"
            next
          end
          
          if path[0] == ?/
            path.gsub!(/^\/*/,'')
          else
            all, pre = /^(.*?\/?)[^\/]*$/.match(page_record.path).to_a
            path = pre + path
          end
          
          URI.escape(path)
        end.compact.uniq
        
        unless links.empty?
          Page.transaction do
            update_list = page_record.site.pages.find(:all, :conditions => ["path in (?)", links])
            
            now = Time.now
            
            create_list = links - update_list.collect { |r| r.path }
            raise "Returned unaccounted record" if create_list.length + update_list.length != links.length
            Page.update_all(['referenced_at = ?, updated_at = ?', now, now], ['id IN (?)', update_list.collect { |r| r.id}])
            
            create_list.each do |path|
              puts " -> #{path.inspect}"
              Page.create(:site => page_record.site, :path => path, :referenced_at => now)
            end
          end
        end
      end
    end
        
    now = Time.now
    page_record.downloaded_at = now
    page_record.invalid = true unless path
    page_record.save!
  end
  
  site = page_record.site
  site.hit_at = now
  site.save!    
end
