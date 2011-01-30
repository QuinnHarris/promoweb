#require 'profile'

require File.dirname(__FILE__) + '/../../config/environment'
require 'adwords'

api = MyWords::API.new
campaign = api.campaigns.find_by_name('Categories NEW')
#unless campaign
#  campaign = api.campaigns.create
#  campaign.name = 'New Categories'
#  campaign.save
#end

adgroups = campaign.adgroups

#adgroup = adgroups.find_by_name('Tools/Flashlights')

#categories = MyWords::Campaign.find_by_name('Categories')

#that = categories.get_adGroups.find_by_name('that')
#crit = that.get_Criterions

Keyword

#adgroups = categories.get_adGroups

#category = Category.find_by_path(['Writing', 'Pens'])
Category.all.collect do |category|
  permute = PhrasePermute.new(category)
  next if permute.noun.empty?
  
  name = category.path_web.join('/')
  puts "Uploading: #{name}"
  adgroup = adgroups.find_by_name(name)
  unless adgroup
    adgroup = adgroups.create
    adgroup.name = name
    adgroup.status = 'Paused'
    adgroup.maxCpc = 1500000
    adgroup.save
  end
  
  creatives = adgroup.creatives
  if creatives.empty?
    creative = creatives.create
    creative.headline = "Promotional #{category.name}"
    if creative.headline.size > 25
      creative.headline = "Custom #{category.name}"[0...25]
    end
    creative.description1 = "Custom imprinted #{category.name.downcase}"[0...35]
    creative.description2 = "Low prices, Great service"
    creative.displayUrl = "www.MountainOfPromos.com"
    creative.destinationUrl = "http://www.mountainofpromos.com/categories/#{name}"
    creative.save
  end
  
#  criterions = adgroup.get_Criterions
  
#  google_list = criterions.collect { |c| c.text }
  criterions = adgroup.criterions.list
  
  add_list = permute.complete.collect do |text|
#    next nil if criterions.find { |c| c.instance_variable_get('@text') == text }
    keyword = AdWords::Keyword.new
    keyword.text = text
    keyword.type = 'Broad'
    keyword
  end
  
  adgroup.criterions = add_list
  
#  exit
  
#  criterions.update(our_list)
  
#  criterions.add_many(our_list - google_list)
#  criterions.remove_many(google_list - our_list)
end


#adwords = AdWords::API.new
#r = adwords.getAllCriteria(that.id)
#
#it = list.collect do |l|
#  k=MyWords::Keyword.new(that)
#  k.text = l;
#  k.type = 'Broad'
#  k
#end
#
#require File.dirname(__FILE__) + '/../config/environment'
#
#class Synonyms
#  def initialize(list)
#    @list = list
#  end
#  
#  def transform(src)
#    src = src.split(' ')
#    @list.each do |syn|
#      idx = syn.index(src)
#      src[idx] = syn
#    end
#    src.flatten.join(' ')
#  end
#end
#
#category_syn = Synonyms.new([
#  %w(padfolio stationary notebook writing\ pad pad book jotter journal organizer ringbinder ringfolio),
#  %w(),
#])
#
#counts = {}
#counts.default = 0
#Category.find_by_path(['Bags', 'Padfolios']).find_products({:include_children => true}).each do |prod|
#  prod.name.split(' ').each { |token| counts[token] += 1 }
#end
#counts.to_a.sort { |l,r| r.last <=> l.last }
#
#
#
#Category.all.collect do |category|
#  name = category.name
#  url = (["http://www.mountainofpromos.com/categories"] + category.path_web).join('/')
#  
#  
#  
#end