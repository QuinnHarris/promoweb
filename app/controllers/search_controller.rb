class SearchController < ApplicationController
  def index
    @stylesheets = ['categories']

    @terms = params[:terms].strip
    @terms = '' unless @terms

    if @terms.upcase[0] == ?M
      num = @terms[1..-1]
      if num == num.to_i.to_s
        begin
          if product = Product.find(num.to_i)
            redirect_to({ :controller => 'products', :action => 'main', :id => product.web_id })
            return
          end
        rescue
        end
      end
    end

    @page = 1
    @page = params[:page].to_i if params[:page]

    if @page == 1
      @categories = Category.find_by_tsearch(@terms, {}, {:headlines => [:name]})
      @categories.each do |cat|
        # Kludge to deal with cat cache
        cat.parent = Category.find_by_id(cat.id).parent
      end
    else
      @categories = []
    end

    @columns = 4
    @rows = 5   
    per_page = @columns*@rows
      
    options = {
      :conditions => 'not deleted',
    }

    # Find by tsearch
    # REALLY INEFFICENT DOESNT USE LIMIT ON DB
    @products = Product.find_by_tsearch(@terms, options, {:headlines => [:name]}).paginate(:page => @page, :per_page => per_page)

    @paginate_options = {}

    # Find by substring search on product name
    if @products.empty?
      terms = @terms.split(/\s+/)
      conditions = "NOT deleted AND " + terms.collect { |t| "(name ILIKE '%#{t}%')" }.join(' AND' )
      @products = Product.paginate(:all, options.merge(:page => @page, :per_page => per_page, 
                    :conditions => conditions, :order => "position('#{terms.first.downcase}' in lower(name))::float / length(name), id"))
    end

    @context = {}

    if @categories.empty?
      if @products.empty?
        render :action => 'notfound'
      elsif @products.size == 1 && @page == 1
        redirect_to({ :controller => '/products', :action => 'main', :id => @products.first.web_id })
      end
    end
  end
end
