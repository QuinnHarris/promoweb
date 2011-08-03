# gem install mechanize
#require 'rubygems'
#gem 'mechanize'
require 'fileutils'

def fetch
  dst_path = File.join(JOBS_DATA_ROOT,'Gemline.xml')
  if File.exists?(dst_path) and
     File.mtime(dst_path) >= (Time.now - 24*60*60)
    puts "File Fetched today"
    return
  end
  
  puts "Starting Fetch"
  
  agent = Mechanize.new
  page = agent.get('http://www.gemline.com/MyGemline/index.aspx')
  form = page.forms.first
  form.fields.find { |f| f.name.include?('txtEmail') }.value = 'mtnexp'
  form.fields.find { |f| f.name.include?('txtPassword') }.value = 'Robert1'
  form.add_field!('ctl00$ContentPlaceHolder1$btnLogin.x','22')
  form.add_field!('ctl00$ContentPlaceHolder1$btnLogin.y','14')
  page = agent.submit(form)
  
  page = agent.get('http://www.gemline.com/MyGemline/distributor-tools/downloads.aspx')
  
  
  form = page.forms.first
  form.add_field!('__EVENTTARGET', 'ctl00$ContentPlaceHolder1$download1$lnkProductDataXML')
  form.add_field!('__EVENTARGUMENT', '')
  page = agent.submit(form)
  
  name = /filename=\"(.*)\"/.match(page.response['content-disposition'])[1]
  path = File.join(JOBS_DATA_ROOT,name)

  page.save_as path
  
  FileUtils.ln_sf(name, dst_path)
  
  puts "Fetched"
end
