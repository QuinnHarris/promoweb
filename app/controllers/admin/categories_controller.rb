class Admin::CategoriesController < Admin::BaseController
  def add
    Category.transaction do
      parent = Category.find_by_id(params[:id])
      child = Category.create(params[:category].merge(:pinned => true, :parent_id => parent.id))
      child.move_to_child_of(parent)
      child.parent = parent
      
      redirect_to :controller => '/categories', :action => :main, :path => child.path_name_list
    end
  end

  def update
    Category.transaction do
      category = Category.find(params[:id])
      category.update_attributes(params[:category])
      category.save!
    end
    redirect_to :back
  end

  def destroy
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
    list.to_a.find do |elem|
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

    logger.info("Cats: #{@categories}")

    render :inline => "<%= content_tag('ul', @categories.collect { |e| content_tag('li', h(e.path)) }) %>"
  end

  @@google_categories = nil
  def auto_complete_for_google_category
    unless @@google_categories
      @@google_categories = File.open(File.join(Rails.root,'lib/taxonomy.en-US.txt')).collect { |l| l.strip }
      logger.info("Loaded Google Categories: #{@@google_categories.length}")
    end

    @list = @@google_categories.find_all { |c| c.include?(params[:category][:google_category]) }
    logger.info("Found: #{@list.inspect}")

    render :inline => "<%= content_tag('ul', @list.collect { |e| content_tag('li', h(e)) }) %>"
  end

  def product_add
    Category.transaction do
      category = Category.find_by_path(params[:path].split('/'))
      product = Product.find(params[:id])

      unless category and product
        render :inline => "Cannot find category or product"
        return
      end
      
      category.pinned = true
      product.categories << category
    end
    redirect_to :back
  end

  def product_remove
    Category.transaction do
      category = Category.find(params[:id])
      product = Product.find(params[:product_id])
      
      product.categories.delete(category)
    end
    redirect_to :back
  end
end
