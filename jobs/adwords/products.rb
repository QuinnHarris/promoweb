require 'rubygems'
require 'adwords'
require File.dirname(__FILE__) + '/../../config/environment'

api = MyWords::API.new
#products_camp = api.campaigns.find_by_name('Products Tail')
#adgroups = products_camp.adgroups
campaigns = api.campaigns

keyword_exclude = [
'Pill',
'Rx',
'Medication',
'Pill-Shaped',
'Tab',
'Tabs',
'Drug',
'Plug/Pill'
]

ad_exclude = keyword_exclude + [
'Cutter Buck',
'Cutter & Buck',
'Zagat',
'Roadster',
'Multi-',
'Multi',
'Apple',
'Cone',
'Econo-',
'Click',
'One-click',
'Euro-click',
'Mint',
'Fireworks',
'Jammer',
'Cigars',
'Cigar',
'Clipper',
'iPod',
'Missile',
'Blade',
'Bmi',
'Astro',
'Power Pack',
'Stp',
'G-Tech',
'Wine Enthusiast',
'Walkabout',
'Popper',
'Maserati',
'Bungee',
'Groovy',
'Innovations',
'Gun',
'Clip-Away',
'Seat',
'Zenith',
'Five-Star',
'On-the-Rocks',
'Econo',
'Nike',
'Bomber',
'Smoking',
'Tape-Tab',
'Webster',
'Klick',
'Uptown',
'On the Rocks',
'Away',
'Colt',
'Speed',
'Skype',
'Slick-Stacker',
'Trade Winds'
]


#supplier_name = 'Gemline'
#Supplier.find_by_name(supplier_name).products.each do |product|
Product.find(:all,
             :conditions => "NOT(deleted) AND supplier_num != '' AND id > 2782",
             :include => :categories,
             :order => 'id' ).each do |product|
  next if product.categories.empty?
  grp = (product.id - 1000) / 2000
  camp_name = "Products #{grp*2000 + 1000}+"
  begin
    products_camp = campaigns.find_by_name(camp_name)
  rescue
  end
  unless products_camp
    products_camp = api.campaigns.create
    products_camp.name = camp_name
    products_camp.budgetAmount = 10000000
    products_camp.budgetPeriod = 'Daily'
#    products_camp.languageTargeting = ['en_US']
#    products_camp.geoTargeting = AdWords::CampaignService::GeoTarget.new
#    products_camp.geoTargeting.countryTargets = ['US']
    products_camp.save
  end

  adgroups = products_camp.adgroups

  supplier_name = product.supplier.name
  adgroup_name = "#{supplier_name}: #{product.supplier_num} (#{product.id})"
  adgroup = nil
  begin
    adgroup = adgroups.find_by_name(adgroup_name)
  rescue
  end
  puts "Ad: #{adgroup_name}"
  unless adgroup
    adgroup = adgroups.create
    adgroup.name = adgroup_name
    adgroup.status = 'Enabled'
    adgroup.keywordMaxCpc = 100000
    adgroup.save
  end
  
  # .gsub(/[^a-zA-Z0-9 \'\-]/,'')
  product_name = product.name.gsub(/\,|\.|\!|\;|%|°|‘|’|”|“|®|–|™|•|\(.*?\)|\&\w+\;/,'').gsub(/ +|\n/, ' ').strip

#  begin
#  ads = adgroup.textads
#  if ads.empty?
  begin
    ad = AdWords::AdService::TextAd.new

    # Headline
    sanitised_name = product_name.dup
    ad_exclude.each do |mark|
      sanitised_name.gsub!(mark, '')
    end
    header = 'Custom '
    if sanitised_name.length > (25 - header.length)
      headline = sanitised_name.split(/ +/)
      while headline.length > 1 and
          headline.join(' ').length > 25
        headline.shift
      end
      headline = headline.join(' ')
    else
      headline = header + sanitised_name
    end
    ad.headline = headline.strip.gsub(/ +/, ' ')

    # Price List
    price_list = product.price_fullstring_cache.split(/ *, */)
    while price_list.join(' ').length > 35
      price_list = price_list[0..-3] + [price_list.last]
    end
    ad.description1 = price_list.join(' ')

    category_list = product.categories.collect { |c| c.name.strip }.uniq
    category_list << "Promotional Products"
    category_list.delete_if do |c|
      c.length > 30 or
        category_list.find { |d| c != d and d.include?(c) } or
        ad_exclude.find { |d| c.include?(d) }
    end
    while category_list.join(', ').length > 30
      category_list.pop
    end
    ad.description2 = "More #{category_list.join(', ')}"

    ad.displayUrl = "www.MountainOfPromos.com"
    ad.destinationUrl = "http://www.mountainofpromos.com/products/main/#{product.id}"

    puts " #{ad.headline}"
    puts "  #{ad.description1}"
    puts "  #{ad.description2}"
    puts "  #{ad.destinationUrl}"
 #   ads.add(ad)

    adgroup.textads = [ad]
  end
#  ads = [ad]
#  rescue => boom
#    puts "Failed: #{product.supplier_num} => #{boom.inspect}"
#    puts boom.detail
#    return
#  end

  keywords = [{ :text => "#{supplier_name} #{product.supplier_num}",
                :type => 'Broad' }]

  unless product.supplier_num.to_i.to_s == product.supplier_num
    keywords << { :text => product.supplier_num.strip,
                  :type => 'Phrase' } 
  end

  word_list = product_name.split(/ +/)
  unless word_list.length <= 1 or product.name.length <= 6
    keyword_exclude.each { |word| word_list.delete(word) }
    keywords << { :text => word_list[0...10].join(' ')[0...80].strip,
                  :type => 'Broad' }
  end
  adgroup.criterions = keywords.collect do |hash|
    obj = AdWords::CriterionService::Keyword.new
    hash.each { |k, v| obj.send("#{k}=", v) }
    obj
  end
  
#  rescue => boom
#    puts "Failed: #{product.supplier_num} => #{boom.inspect}"
#  end
end
