require 'hpricot'
Hpricot.buffer_size = 256*1024 #262144

class DigispecWeb < GenericImport
  def initialize
    super "DigiSpec"
  end

  @@data_path = File.join(JOBS_DATA_ROOT, 'Digispec')

  def image_paths
    return @image_paths if @image_paths
    @image_paths = {}
    Dir["#{@@data_path}/**/*.jpg"].each do |file|
      if /\/(\w+)\.jpg$/ === file
        raise "Duplicate image: #{file} #{@image_paths[$1]}" if @image_paths[$1]
        @image_paths[$1] = file
      end
    end
    @image_paths
  end

  def parse_page(url)
    image_paths
    puts "Page: #{url}"
    fetch = WebFetch.new(url)
    doc = Hpricot(open(fetch.get_path))

    pxtable = doc.search("//table.pxTable")
    full_title = pxtable.search("thead/tr/th").inner_html
    raise "Unknown Title: #{full_title}" unless /^(.+)Pricing/ === full_title
    title = $1.strip

    description = doc.at("div[@class='advantages']/p").inner_html.strip + "\n"
    description += doc.search("div[@class='advantages']/ul/li").collect { |l| l.inner_html.strip.gsub(/<.+?>/,'') }.join("\n")

    header = pxtable.search("thead/tr/td").collect { |td| td.inner_html }
    quantities = header[3..-1].collect { |q| Integer(q) }

    head_col = nil
    variants = pxtable.search("tbody/tr").collect do |row|
      columns = row.search('td')
      cells = row.search('td').collect { |t| t.inner_html }
      if cells.length > quantities.length + 2
        head_col = cells.shift.gsub(/\s*<.+?>\s*/,' ').strip
        puts "Head: #{head_col}"
      end

      dim_list = cells.shift.split(/\s*x\s*/)
      thickness = dimension = nil
      if dim_list.length == 3 || dim_list.last.include?('Round')
        thickness = dim_list.first
        dimension = dim_list[1..-1].join(' x ')
      else
        dimension = dim_list.join(' x ')
      end

      num = cells.shift

      prices = quantities.zip(cells).collect do |q, p|
        { :minimum => q,
          :marginal => Money.new(Float(p)),
          :fixed => Money.new(0) }
      end

      costs = [{ :minimum => prices.first[:minimum],
                 :marginal => prices.last[:marginal] * 0.65,
                 :fixed => Money.new(0) },
               { :minimum => Integer(prices.last[:minimum]*1.5) }]


      image = ImageNodeFile.new(num, image_paths[num]) if image_paths[num]
      
      { 'supplier_num' => num,
        'prices' => prices,
        'costs' => costs,
        'base' => head_col,
        'thickness' => thickness,
        'dimension' => dimension,
        'images' => [image],
      }
    end

    # Imprint 
    imprint_list = doc.search("//strong[text() = 'Imprint:']/..//text()").to_a[2..-1]
    technique = imprint_list.first.to_s.strip

    base_name = File.basename(url).gsub('.php', '')
    thumb_path = File.join(@@data_path, 'Thumbs', "#{base_name}.png")
    if File.exists?(thumb_path)
      thumbs = [ImageNodeFile.new(base_name, thumb_path)]
    else
      thumbs = nil
      puts "No thumb for: #{base_name}"
    end

    { 'supplier_num' => base_name,
      'name' => title,
      'description' => description,
      'variants' => variants,
      'decorations' => [{'technique' => technique, 'location' => ''}],
      'supplier_categories' => [['Mouse Pads']],
      'lead_time_normal_min' => 5,
      'lead_time_normal_max' => 6,
      'lead_time_rush' => 1,
      'lead_time_rush_charge' => 0.3,
      'data' => { :url => url },
      'images' => thumbs,
      'price_params' => { :n1 => 100, :m1 => 1.5, :n2 => 2500, :m2 => 1.2 }
    }
  end

  def parse_products
    url_base = 'http://www.digispec.com'
    fetch = WebFetch.new("#{url_base}/mousepads/index.php")
    doc = Hpricot(open(fetch.get_path))

    pages = doc.search("//div.advantages/a").collect { |a| a['href'] }
    pages -= ["/mousepads/mpcalendars.php"]
    pages.each do |page|
      res = parse_page("#{url_base}#{page}")
      add_product(res)
    end
  end
end
