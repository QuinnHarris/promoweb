class Admin::PromoteController < Admin::BaseController 
private
  def perm_recurse(list)
    return [] if list.size == 1
    ([list] + 
    [[list.first]] + perm(list[1..-1]) +
    perm(list[0..-2]) + [[list.last]])
  end
  
  def perm(list)
    perm_recurse(list).uniq
    #.sort { |l, r| r.size <=> l.size}
  end

public
  def category
    @category = Category.find_by_id(params[:id])
    
    tokens = {}
    tokens.default = 0
    @category.find_products({:children => true}).each do |prod|
      next if prod.name.empty?
      list = perm(prod.name.split(' '))
      list.each do |token|
        tokens[token.join(' ')] += 1
      end
    end
    tokens.delete_if { |token, count| count == 1 }
    @list = tokens.to_a.sort { |l,r| r.last <=> l.last }[0..100]
    
    @keyword_types = %w(Adjective Noun Include Exclude)
    
    @keywords = @keyword_types.inject({}) do |hash, type|
      keywords = @category.keywords.find(:all, :conditions => "name = '#{type}'")
      hash[type] = keywords
      keywords.each do |keyword|
        @list.delete_if { |phrase, (count, acc)| phrase == keyword.phrase }
      end
      hash
    end
  end
  
  def categories_phrases
    Keyword
    
    @category = Category.find_by_id(params[:id])
    
    permute = PhrasePermute.new(@category)
    
    @phrases = permute.complete
  end
  
private
  def category_keywords_render
    keywords = @category.keywords.find(:all, :conditions => "name = '#{params[:type]}'")
    
    render_partial 'keyword_list', :keywords => keywords
  end
  
public
  def category_keyword_add
    @category = Category.find_by_id(params[:id])
    
    keyword = Keyword.get(params[:keyword])
    @category.keywords.push_with_attributes(keyword, :name => params[:type])
    
    category_keywords_render
  end
  
  def category_keyword_delete
    @category = Category.find_by_id(params[:id])
    
    keyword = Keyword.find(params[:keyword])
    @category.keywords.delete(keyword)
    
    category_keywords_render
  end
  
  def competitors
    @pages = Page.find(:all,
      :include => [:site, [:page_products => [:product =>:supplier]]],
      :conditions => "pages.id IN (SELECT page_id FROM page_products)",
      :order => 'site_id, title')
      
#    @pages.sort_by { |p| p.page_products.product_id }
  end
  
  def product_list
    @products = Product.find(:all,
      :include => [:supplier],
      :order => "products.id")
      
    page_products = {}
    page_products.default = []
    Page.find(:all,
      :include => [:site, [:page_products => :page]],
      :conditions => "pages.id IN (SELECT page_id FROM page_products)",
      :order => 'site_id, title').each do |page|
        page.page_products.each do |pp|
          pp.page.target = page
          page_products[pp.product_id] += [pp]
        end
    end
      
    @products.each do |prod|
      prod.page_products.target = page_products[prod.id]
    end
  end
  
  def competitor_verify
    render :layout => false
  end
  
  def competitor_verify_index
    if params[:id] and params[:correct]
      PageProduct.transaction do
        @prev_pp = PageProduct.find(params[:id])
        @prev_pp.correct = case params[:correct]
                     when 't'
                       true
                     when 'f'
                       false
                     else
                       nil
                     end
        @prev_pp.save!
        
        if @prev_pp.correct
          (@prev_pp.page.page_products + @prev_pp.product.page_products).each do |p|
            next unless p.page.site_id == @prev_pp.page.site_id
            if p.correct.nil?
              p.correct = false
              p.save!
            end
          end
        end
      end
    end

    pp_conditions = "correct IS NULL AND NOT (request_uri LIKE '%24hr%') AND score <= 100.0"


    @pp = PageProduct.find(:first,
                             :include => [{ :page => :site }],
                             :conditions => pp_conditions,
                             :order => 'page_products.score DESC, pages.id, page_products.product_id, pages.site_id')

    @remain = PageProduct.count(:include => :page, :conditions => pp_conditions)
    @match = PageProduct.count(:conditions => "correct = 't'")

    render :layout => false
  end
end
