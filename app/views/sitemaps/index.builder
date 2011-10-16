xml.instruct! :xml, :version=> '1.0', :encoding => 'UTF-8'
xml.sitemapindex( :xmlns => 'http://www.sitemaps.org/schemas/sitemap/0.9') do
  for sitemap in @sitemaps
    xml.sitemap do
      xml.loc sitemap[:loc]
      xml.lastmod sitemap[:lastmod] if sitemap[:lastmod]
    end
  end
end