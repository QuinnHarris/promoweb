require 'sites'

require 'hpricot'
Hpricot.buffer_size = 262144

Site
#Site.find(:all).each do |site_record|
$file_cache = FileCache.new('spider')
site_record = Gimmees.find(:first)
  source_record = PriceSource.get_by_name(site_record.url)
  site_record.pages.find(:all, :include => :site,
    :conditions => "NOT NULLVALUE(fetch_complete_at) AND pages.id NOT IN " +
      '(SELECT page_id FROM page_products WHERE score > 100.0 OR correct)',
    :order => 'fetch_complete_at DESC').each do |page_record|

    if page_record.product_page?
      puts "URL: #{page_record.url}"
      next unless res = $file_cache.get(URI.parse(page_record.url))
      next unless doc = Hpricot(res.body)
      title = site_record.title(doc)
      puts " Title: #{title}"
      
      unless page_record.title == title 
        page_record.title = title 
        page_record.save!
      end
      
      products = site_record.canidate_products(doc)
      next if products.empty?
            
      existing = page_record.page_products.to_a
      
      pp = products.collect do |score, prod|
        if page = existing.find { |p| p.product_id == prod.id }
          existing.delete(page)
          next if page.score == score
        else
          page = PageProduct.new(:page => page_record, :product => prod)
        end        
        page.score = score
        page.save!
      end
      
      unless existing.empty?
        puts "EXISTING"
        existing.each do |pp|
          next unless pp.correct.nil?
          pp.destroy
        end
      end
    end
  end
#end
