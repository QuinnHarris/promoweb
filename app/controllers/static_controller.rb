class StaticController < ApplicationController
  @@pages = [
   ['About Us', 'about', 'About Us'],
   ['Ordering', 'order', 'Order Information'],
   ['Artwork', 'artwork', 'Artwork Requirements'],
   ['Colors', 'color_chart', 'Pantone Color Chart'],
  ]
  
  @@hidden_pages = [
   ['Internet Explorer', 'ie'],
   ['Copyright', 'copyright'],
   ['Candy Fills', 'fills'],
   ['Must Login', 'login']
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
