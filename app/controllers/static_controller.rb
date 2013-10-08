class StaticController < ApplicationController
  layout 'static'

  before_filter :setup_context

  @@pages = [
   ['About Us', 'about', 'About Mountain Xpress Promotions'],
   ['Ordering', 'order', 'Order Information for Mountain Xpress Promotions'],
   ['Artwork', 'artwork', 'Artwork Requirements'],
   ['Decorations', 'decorations', 'Product Decorations'],
   ['Colors', 'color_chart', 'Pantone Color Chart'],
  ]
  
  @@hidden_pages = [
   ['Copyright', 'copyright'],
   ['Candy Fills', 'fills'],
   ['Must Login', 'login'],
   ['Bitcoin', 'bitcoin', 'Buy custom printed promotional products with bitcoin']
  ]
  
  cattr_reader :pages, :hidden_pages
  
  before_filter :set_title
  def set_title
    record = (@@pages + @@hidden_pages).find { |p| p[1] == params[:action] }
    puts "Title: #{@@pages.inspect}"
    @title = record[2] if record
  end

  def sitemap
    headers['Content-Type'] = 'text/xml; charset=utf-8'
    @links = @@pages.collect do |name, link, title|
      { :loc => "http://www.mountainofpromos.com/static/#{link}" }
    end
    render :template => 'sitemaps/sitemap', :layout=>false
  end
end
