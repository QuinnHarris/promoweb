#require 'scruffy'

module Scruffy::Layers
  class Line < Base
    # Renders line graph.
    def draw(svg, coords, options={})
      svg.polyline( :points => stringify_coords(coords).join(' '), :fill => 'none',
                    :stroke => color.to_s, 'stroke-width' => relative(@options[:stroke_width] || 2) )
    end  
  end
  
  class Xy < Line
  protected
    def generate_coordinates(options = {})
      x_mult = width / (@options[:maximum_key] || points.maximum_key).to_f

      points.collect do |x, y|
        x_coord = x * x_mult

        relative_percent = ((y == min_value) ? 0 : ((y - min_value) / (max_value - min_value).to_f))
        y_coord = (height - (height * relative_percent))
        
        [x_coord, y_coord]
      end.sort_by { |x, y| x }
    end
  end
end

# Kludge to fix "viewBox"
module Scruffy::Renderers
  class Base
    # Renders the graph and all components.
    def render(options = {})
      options[:graph_id]    ||= 'scruffy_graph'
      options[:complexity]  ||= (global_complexity || :normal)

      # Allow subclasses to muck with components prior to renders.
      rendertime_renderer = self.clone
      rendertime_renderer.instance_eval { before_render if respond_to?(:before_render) }

      svg = Builder::XmlMarkup.new(:indent => 2)
      svg.instruct!
      svg.declare!(:DOCTYPE, :svg, :PUBLIC, "-//W3C//DTD SVG 1.1//EN", "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd")
      svg.svg(:xmlns => "http://www.w3.org/2000/svg", 'xmlns:xlink' => "http://www.w3.org/1999/xlink") {
        svg.g(:id => options[:graph_id]) {
          rendertime_renderer.components.each do |component|
            component.render(svg, 
                             bounds_for( options[:size], component.position, component.size ), 
                             options)
          end
        }
      }
      svg.target!
    end
  end
end

module Scruffy
  module Components
    class DataMarkers < Base
      def draw(svg, bounds, options={})
        unless options[:point_markers].nil?
          x_mult = bounds[:width] / options[:point_markers].keys.max.to_f
          
          options[:point_markers].each do |x, name|
            x_coord = x * x_mult
            svg.text(name,
              :x => x_coord,
              :y => bounds[:height],
              'font-size' => relative(90),
              'font-family' => options[:theme].font_family,
              :fill => (options[:theme].marker || 'white').to_s,
              'text-anchor' => 'middle') unless name.nil?
          end
        end
      end   # draw
    end   # class
  end
end


class Admin::ProductsController < Admin::BaseController
  autocomplete :supplier, :name
  def new
    @product = Product.new
  end
  
  def create
    Product.transaction do
      supplier_name = params[:supplier][:name].strip
      supplier = Supplier.find_by_name(supplier_name)
      unless supplier
        supplier = Supplier.create(:name => supplier_name,
          :price_source => PriceSource.create(:name => params[:supplier][:name]))
      end
      product = supplier.products.create(params[:product])
      variant = product.variants.create(:supplier_num => params[:product][:supplier_num])
      cost_group = variant.price_groups.create(:exponent => 0.0, :coefficient => 1.0)
      cost_group.price_entries.create(:minimum => 1, :fixed => Money.new(0), :marginal => Money.new(10000))
      cost_group.price_entries.create(:minimum => 1000)
      price_group = variant.price_groups.create(:source => supplier.price_source)
      price_group.price_entries.create(:minimum => 1, :fixed => Money.new(0), :marginal => Money.new(20000))
      price_group.price_entries.create(:minimum => 1000)

      unless params[:product_image][:image].blank? and params[:product_image][:url].blank?
        pi = product.product_images.create(:supplier_ref => params[:product][:supplier_num])
        unless params[:product_image][:url].blank?
          require 'open-uri'
          pi.image = URI.parse(params[:product_image][:url]).open
        else
          pi.image = params[:product_image][:image]
        end

        pi.image.save
        pi.save!
      end

      if params[:context][:order_id]
        @order = Order.find(params[:context][:order_id])
        item = @order.items.create(:product_id => product.id, :price_group_id => price_group.id)
        item.order_item_variants.create(:variant_id => variant.id, :quantity => 100)
        @order.task_complete({ :user_id => session[:user_id], :host => request.remote_ip,
                               :data => { :product_id => product.id, :item_id => item.id }},
                      AddItemOrderTask, [AddItemOrderTask, RequestOrderTask, RevisedOrderTask, QuoteOrderTask])
        redirect_to items_admin_order_path(@order)
      else
        redirect_to product_path(product)
      end
    end
  end
  
  def edit
    @product = Product.find(params[:id])
    @supplier = @product.supplier
  end
  
  def update
    product = Product.find(params[:id])
    product.update_attributes(params[:product])

    unless params[:product_image][:image].blank? and params[:product_image][:url].blank?
      pi = product.product_images.first || product.product_images.create(:supplier_ref => params[:product][:supplier_num])
      unless params[:product_image][:url].blank?
        require 'open-uri'
        pi.image = URI.parse(params[:product_image][:url]).open
      else
        pi.image = params[:product_image][:image]
      end
      pi.image.save
      pi.save!
    end   

    redirect_to :controller => '/products', :action => :show, :id => product
  end
  
  def chart
    product = Product.find(params[:id])
    collection = PriceCollectionCompetition.new(product)
    collection.calculate_price

    max_x = collection.all_minimums.last
    max_x_log = Math.log(max_x)
    min_x = collection.all_minimums.first
    min_x_log = Math.log(min_x)
    
    graph = Scruffy::Graph.new
    graph.title = "#{product.name} Prices"
    graph.renderer = Scruffy::Renderers::Standard.new
    graph.value_formatter = Scruffy::Formatters::Currency.new
    
    
    # Competitor Prices
    (collection.price_groups + collection.cost_groups).sort_by { |g| g.source_id ? 0 : 1 }.each do |group|
      name = group.source_id ? group.source.name : 'Cost'
      last_y_marginal = nil
      last_y_fixed = nil
      last_min = nil
      cords = group.price_entries.to_a.inject({}) do |hash, entry|
        hash[Math.log(entry.minimum - 1) - min_x_log] = last_y_marginal + last_y_fixed / entry.minimum.to_f if last_y_marginal
        next hash unless entry.minimum and !entry.marginal.nil?
        
        last_y_marginal = entry.marginal.to_f
        last_y_fixed = entry.fixed.to_f
        hash[Math.log(last_min = entry.minimum) - min_x_log] = last_y_marginal + last_y_fixed / entry.minimum.to_f
        hash
      end
      thin = group.source_id and group.source_id != product.supplier.price_source_id
      graph.add :XY, name.strip, cords, :maximum_key => max_x_log - min_x_log, :stroke_width => thin && 1
    end
    
    [[collection.price_sets, 'Our', nil], [collection.price_bounds, '', 0.5]].each do |sets, name, width|
      sets.each do |price_set|
        list = {}
  
        price_set.breaks[0..-2].zip(price_set.breaks[1..-1]).each do |cur, nxt|
          cur_x = Math.log(n = cur.minimum)
          nxt_x = Math.log(nxt.minimum-1)
          step = (nxt_x - cur_x) / ((nxt_x - cur_x)/0.1).ceil
          while cur_x < nxt_x
            list[cur_x - min_x_log] = cur.price_at(n).to_f
  #          logger.info("Price: #{n} = #{list[cur_x - min_x_log]} (#{cur.marginal})")
            last_n = n
            while n == last_n
              cur_x += step
              n = (Math::E**(cur_x)).to_i
            end
          end
          list[nxt_x - min_x_log] = cur.price_at(nxt.minimum-1).to_f
        end
        graph.add :xy, name, list, :maximum_key => max_x_log - min_x_log, :stroke_width => width
      end
    end
    
    begin # X scale
      last_x = nil
      graph.point_markers =
        collection.all_minimums.inject({}) do |hash, min|
          x = Math.log(min) - min_x_log
          hash[last_x = x] = min if last_x.nil? or ((x - last_x) / (max_x_log - min_x_log)) > 0.08
          hash
        end
    end
    
    # Set Vertical Scale
    max_markers = 8
    top = graph.top_value.ceil
    step = (top * 4.0 / max_markers).ceil / 4.0
    markers = (top / step).to_i

    svg = graph.render :min_value => 0, :max_value => markers*step, :markers => markers+1, :width => 1000
    render :inline => svg, :content_type => "image/svg+xml"
  end
end
