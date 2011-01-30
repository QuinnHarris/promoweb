module CategoriesHelper
  def setup_home
#    products = Category.root.products_featured(:children => true, :include => :categories)
    products = Product.find(:all, :include => [:variants => [:price_groups => :order_items]],
                            :select => 'products.*', :order => 'order_items.id DESC', :limit => 20)
    
    assigned = {}
    assigned.default = []
    
    cat_hash = {}
    cat_hash.default = []    
    products.each do |prod|
      prod.categories.each do |cat|
        cat = Category.find_by_id(cat.id)
        ([Category.root] + cat.path_obj_list).each do |cat|
          cat_hash[cat] += [prod] unless cat_hash[cat].index(prod); 
        end
      end
    end
        
    list = cat_hash.to_a.sort { |l, r| l.last.size <=> r.last.size }
    
    until list.empty? or list.first.first == Category.root
      category = list.first.first
      product = list.shift.last
      
      if product.size >= 3
        assigned[category] = product
        list.delete_if do |cat, prods|
          prods.delete_if { |prod| product.index(prod) }
          prods.empty?
        end
      end
    end

    @featured = assigned.collect do |cat, lst|
      [cat, lst.uniq.sort { |l,r| l.price_min_cache <=> r.price_min_cache}]
    end.sort { |l, r| l.first.name <=> r.first.name }
    
    @featured.unshift([Category.root, list.shift.last]) unless list.empty?
    
    @limit = CategoriesController.rows * CategoriesController.columns
  end
end
