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
#      @categories = Category.find_by_tsearch(@terms, {}, {:headlines => [:name]})
      @categories = Category.search(@terms)
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

    @products =  WillPaginate::Collection.create(@page, per_page, 0) do |pager|
      scope = Product.search(@terms).where(:deleted => false)
      list = scope.includes(:product_images).limit(per_page).offset((@page-1)*per_page)
      pager.replace list[0...per_page]
      pager.total_entries = list.length > per_page ? scope.count : ((@page-1)*per_page + list.length)
    end

    @paginate_options = {}

    # Find by substring search on product name
    @products =  WillPaginate::Collection.create(@page, per_page, 0) do |pager|
      scope = Product.where(:deleted => false)
      @terms.split(/\s+/).each { |t| scope = scope.where(["name ILIKE '%?%'", t]) }
      list = scope.order("id").includes(:product_images).limit(per_page).offset((@page-1)*per_page)
      pager.replace list[0...per_page]
      pager.total_entries = scope.count
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
