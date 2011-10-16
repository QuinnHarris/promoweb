xml.instruct! :xml, :version=> '1.0', :encoding => 'UTF-8'
xml.urlset( :xmlns => 'http://www.sitemaps.org/schemas/sitemap/0.9') do
  for link in @links
    xml.url do
      xml.loc link[:loc]
      xml.lastmod link[:lastmod] if link[:lastmod]
      xml.changefreq 'weekly'
      xml.priority '0.5'
    end
  end
end
