require 'sites'

fc = FileCache.new("spider")

Site
site_record = Gimmees.find(:first)
site_record.pages.find(:all,
  :order => 'fetch_complete_at NULLS LAST').each do |page_record|
    
    request_uri = site_record.normalize_uri(page_record.request_uri)
    if request_uri != page_record.request_uri
      puts "#{page_record.request_uri} -> #{request_uri}"
      norm_uri = URI.parse("http://#{site_record.url}/#{request_uri}")
      
      norm_page = site_record.pages.find_by_request_uri(request_uri)
      if norm_page
        puts " Delete"
        fc.delete(URI.parse(page_record.url))
        page_record.destroy
      else
        puts " Move"
        if fc.exists?(URI.parse(page_record.url))
          fc.move(URI.parse(page_record.url), norm_uri)
        end
        page_record.request_uri = request_uri
        page_record.save!
      end
      
#      if fc.exists?(norm_uri)
#        fc.delete(norm_uri)
#      else
#        File.move(fc.file_path(URI.parse(page_record.url)), fc.file_path(norm_uri))
#      end
    end

    unless site_record.include_uri?(page_record.request_uri)
      puts "REMOVE: #{page_record.request_uri}"
      fc.delete(URI.parse(page_record.url))
      page_record.destroy
    end

  end
