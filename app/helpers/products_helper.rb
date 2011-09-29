module ProductsHelper 
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
    @product.association(:variants).target = @product.variants.find(:all, :include => :properties)
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
