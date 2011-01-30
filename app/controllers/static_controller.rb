class StaticController < ApplicationController
  @@pages = [
   ['About Us', 'about'],
   ['Order Information', 'order'],
   ['Artwork Requirements', 'artwork'],
   ['Color Chart', 'color_chart'],
#   ['Lead Times', 'lead_times'],
   ['Privacy Policy', 'privacy'],
  ]
  
  @@hidden_pages = [
   ['Internet Explorer', 'ie'],
   ['Copyright', 'copyright'],
   ['Candy Fills', 'fills']
  ]
  
  cattr_reader :pages, :hidden_pages
  
  before_filter :set_title
  def set_title
    record = (@@pages + @@hidden_pages).find { |p| p.last == params[:action] }
    @title = record.first if record
  end

  def sitemap
    headers['Content-Type'] = 'text/xml; charset=utf-8'
    @links = @@pages.collect do |name, link|
      { :loc => "http://www.mountainofpromos.com/static/#{link}" }
    end
    render :template => 'sitemaps/sitemap', :layout=>false
  end
end
