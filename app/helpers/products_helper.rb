module ProductsHelper
  # Wholly shit don't look
  def recurse(lst)
    elems = lst.collect { |c| c.first }.uniq.sort { |l, r| l.name <=> r.name }
    "<ul>" + elems.collect do |elem|
      values = lst.find_all { |c| c.first == elem }.collect { |c| c[1..-1] if c.size > 1 }.compact
      values = nil if values.empty?
      is_root = (elem.name == 'root')
      link = is_root ? "Home Page" : elem.name
      link = link_to(link, :action => 'set_featured', :id => @product, :category => elem)
      link = "(#{link})" if @category == elem
      if @product.featured_id == elem.id
        if idx = elem.products_featured({:limit => is_root ? nil : CategoriesController.featured_items, :children => values}).index(@product)
          link = "<strong>#{link}</strong> (#{idx+1})"
        else
          link = "<em>#{link}</em>"
        end
      end
      link = "<li>#{link}"
      link += recurse(values) if values
      link += "</li>"
    end.join + "</ul>"
  end
  
  def treething(categories)
    root = Category.root
    lst = categories.collect { |c| [root] + c.path_obj_list }
    recurse(lst)
  end
  
  def path_tail_list
    list = (@categories - [@category]).collect do |category|
      category_path(category)
    end
    return '' unless list
    '<ul>' +
    list.collect { |i| "<li>#{i}</li>" }.join +
    '</ul>'
    
  end

  def format_leed_time(days)
    if days % 5 == 0
      weeks = days / 5
      "#{weeks} week#{weeks > 1 ? 's' : ''}"
    else
      "#{days} day#{days > 1 ? 's' : ''}"
    end
  end
  
  def setup_main
    # Properties
    @product.variants.target = @product.variants.find(:all, :include => :properties)
    @common_properties = @product.common_properties
    @properties = @product.variant_properties
    
    # Decorations
    @decorations = @product.decorations.find(:all, :include => [:technique])
    #      decorations = @decorations.find_all { |x| x.technique.name != 'None' }
        
    @techniques = @decorations.collect { |dec| dec.technique }.uniq.sort
    @locations = @decorations.collect { |dec| dec.location }.uniq

    @decoration_hash = @decorations.inject({}) do |hash, dec|
      hash[[dec.location, dec.technique]] = dec
      hash
    end
        
        
        # Prices
#    @prices = PriceCollectionCompetition.new(@product)
#    @prices.calculate_price
    @prices = (@user ? PriceCollectionAll : PriceCollection).new(@product)
    @prices.adjust_to_profit!
      
    @minimums = @prices.minimums
    return if @minimums.empty?
    @minimums = [@minimums.first] + @minimums[-5..-2] if @minimums.length > 5
    
    if @minimums.length < 5
      @minimums += @minimums[1..-1].zip(@minimums).collect do |cur, lst|
        count = (((cur-1).to_f/lst.to_f) / 3.0).to_i + 1
        (1...count).collect do |i|
          lst + ((cur - lst) * i) / count
        end
      end.flatten[0...(5-@minimums.length)]    
      @minimums.sort!
    end
  end
end
