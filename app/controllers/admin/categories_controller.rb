class Admin::CategoriesController < Admin::BaseController
  def add
    Category.transaction do
      parent = Category.find_by_id(params[:id])
      child = Category.create(params[:category].merge(:pinned => true, :parent_id => parent.id))
      parent.add_child(child)
      child.parent = parent
      
      redirect_to :controller => '/categories', :action => :main, :path => child.path_name_list
    end
  end

  def remove
    Category.transaction do
      child = Category.find_by_id(params[:id])
      parent = child.parent
      child.destroy
    
      redirect_to :controller => '/categories', :action => :main, :path => parent.path_name_list
    end
  end

private
  def find_categories(list, phrase, limit)
    #logger.info("List: #{list.collect { |l| l.name }.join(', ')}")
    result = []
    list.find do |elem|
      next unless elem.children
      result += elem.children.find_all { |child| child.name.downcase.include?(phrase) }
      #logger.info("Result: #{result.collect { |l| l.name }.join(', ')}")
      result.length >= limit
    end
    unless result.length >= limit
      list.find do |elem|
        next unless elem.children
        result += find_categories(elem.children, phrase, limit - result.length)
        result.length >= limit
      end
    end
    result[0...limit]
  end
public

  def auto_complete_for_path
    @categories = [Category.root]
    path = params[:path].split('/')
    limit = 10*path.length
    path.each do |phrase|
      phrase.downcase!
      @categories = find_categories(@categories, phrase, limit)
      limit /= 10
    end

    render :inline => "<%= content_tag('ul', @categories.collect { |e| content_tag('li', h(e.path)) }) %>"
  end

  def add_product
    Category.transaction do
      category = Category.find_by_path(params[:path].split('/'))
      product = Product.find(params[:id])

      unless category and product
        render :inline => "Cannot find category or product"
        return
      end
      
      product.categories << category
    end
    redirect_to :back
  end

  def remove_product
    Category.transaction do
      category = Category.find(params[:category])
      product = Product.find(params[:id])
      
      product.categories.delete(category)
    end
    redirect_to :back
  end
end
