class GeneralController < ApplicationController  
  def sitemaps
    @sitemaps = %w(products categories static).collect do |name|
      { :loc => "http://www.mountainofpromos.com/#{name}/sitemap" }
    end
  
    render :template => 'sitemaps/index', :layout=>false
  end
end
