class PriceBand
  def initialize(set, marginal, fixed, minimum)
    @set, @marginal, @fixed, @minimum = set, marginal, fixed, minimum
  end
  
  attr_reader :marginal, :fixed, :minimum
  def const; @set.const; end
  def exp; @set.exp; end
  
  def marginal_at(n)
    return Money.new(0) if n == 0
    marginal.nil? ? nil : (marginal + const * (n ** exp)).round_cents
  end
  
  def pair_at(n)
    PricePair.new(marginal_at(n), fixed)
  end
  
  def price_at(n)
    (fixed.nil? and marginal.nil?) ? nil :
      ((fixed/n).round_cents + marginal_at(n))
  end
  
  def profit_at(n)
    (price_at(n) - marginal) * n - fixed
  end
  
  def n_at_profit(profit)
    ((profit.to_f / const.to_f) ** (1/(exp+1))).ceil
  end

  def set_minimum(min)
    raise "Can't lower min" if min < minimum
    @minimum = min
  end
  
  def adjust_to_profit!(profit, max = nil)
    n = n_at_profit(profit)
    raise "Adjust to profix MAX: #{n} >= #{max}" if max and n >= max
    return minimum if n < minimum
    @minimum = n
  end
end

class PriceSet
  @@required_profit = Money.new(100.00)
  cattr_reader :required_profit
  
  def initialize(group, const, exp, count = nil)
    @group, @const, @exp, @count = group, const, exp, count

    cost_entries = group.price_entries.sort_by { |e| e.minimum }
    
    @breaks = cost_entries.collect do |cost_entry|
      PriceBand.new(self, cost_entry.marginal, cost_entry.fixed, cost_entry.minimum)
    end
  end

  def adjust_to_profit!
    # Adjust to required profit
    n = nil
    while (@breaks.length > 1) and
        ((n = @breaks[0].n_at_profit(@@required_profit)) >= @breaks[1].minimum)
      @breaks.shift
    end
    if n > @breaks[0].minimum
      @breaks[0].set_minimum(n)
      return n
    else
      return @breaks[0].minimum
    end
  end
  
  attr_reader :group, :breaks, :const, :exp
  
  def break_at(n)
    index = @breaks.index(@breaks.find { |b| b.minimum > n })
    index = (index ? index : breaks.size) - 1
    return false if index == -1
    @breaks[index]
  end
    
  def total_at(n = @count)
    unit = marginal_at(n)
    fixed = fixed_at(n)
    return nil if (unit.nil? or fixed.nil?)
    return false unless (unit and fixed)
    return unit * n + fixed
  end
  
  def price_at_minimum
    breaks.first.price_at(breaks.first.minimum)
  end

  def normal_minimum
    breaks.find { |b| b.fixed.to_i == 0 }.minimum
  end
  
  def price_at_competative
    price = price_at_minimum
    price.round_cents * breaks.first.minimum if price
  end
  
  # !!! Incorrect until real continiuous pricing
  def price_at_maximum
    qty = breaks.last.minimum
    qty -= 1 unless breaks.empty?
    brk = breaks.last.marginal.nil? ? breaks[-2] : breaks[-1]
    return nil unless brk
    brk.price_at(qty)
  end
  
  def maximum
    breaks.last.minimum-1
  end

  def price_at(n = @count)
    brk = break_at(n)
    return false unless brk
    brk.price_at(n)
  end
  
  def marginal_at(n = @count)
    brk = break_at(n)
    return false unless brk
    brk.marginal
  end
  
  def fixed_at(n = @count)
    brk = break_at(n)
    return false unless brk
    brk.fixed
  end
  
  def pair_at(n = @count)
    brk = break_at(n)
    return false unless brk
    brk.pair_at(n)
  end
end

class PriceCollection
  def initialize(product, count = nil)
    @count = count
    
    groups = PriceGroup.find(:all,
      :conditions => ["(price_groups.source_id IS NULL OR price_groups.source_id = ?) AND variants.product_id = ?",
                      product.supplier.price_source_id, product.id],
      :order => 'variants.id',
      :include => [:variants, :price_entries])
    
    @cost_groups = groups.find_all { |g| g.source_id.nil? }
    @supplier_groups = groups - @cost_groups

    unless @cost_groups.length == @supplier_groups.length
      cost_variants = @cost_groups.collect { |g| g.variants }.flatten.uniq
      supplier_variants = @supplier_groups.collect { |g| g.variants }.flatten.uniq
      if @cost_groups.length == 1 and (cost_variants & supplier_variants).length == cost_variants.length
        @cost_groups = (1..@supplier_groups.length).collect { @cost_groups.first }
      else
#        raise "Unmatched cost/supplier groups: #{@cost_groups.inspect} != #{@supplier_groups.inspect}" 
      end
    end

    @price_sets = @cost_groups.collect do |cost_group|
      next nil unless cost_group.coefficient and cost_group.exponent
      PriceSet.new(cost_group, Money.new(cost_group.coefficient.to_f), cost_group.exponent, @count)
    end.compact

    @supplier_minimums = @supplier_groups.collect { |g| g.price_entries.collect { |e| e.minimum } }.flatten.sort.uniq
      
    @minimums = @price_sets.collect { |s| s.breaks.collect { |e| e.minimum } }.flatten.sort
    @minimums = (@minimums + @supplier_minimums.find_all { |n| n > @minimums.first }).sort.uniq unless @minimums.empty?
  end

  def adjust_to_profit!
    mins = @price_sets.collect { |ps| ps.adjust_to_profit! }
    mins = [mins.min, mins.max] # Ignore the minimum profits in the middle
    @minimums = (@minimums.find_all { |n| n >= mins.min } + mins).sort.uniq
  end

  def bounded?
    !!@price_sets.find { |s| s.breaks.last.marginal.nil? }
  end
    
  attr_reader :cost_groups, :supplier_groups, :price_sets, :minimums, :supplier_minimums
  
  %w(price unit fixed total).each do |name|
    define_method "#{name}_range" do |qty|
      list = @price_sets.collect { |set| set.send("#{name}_at", qty) }
      return MyRange.new(nil, nil) if list.index(nil)
      return MyRange.new(false, false) if list.index(false)
      return MyRange.new(list.min, list.max)
    end
  end
end

class PriceCollectionAll < PriceCollection
  def initialize(product, count = nil)
    super product, count

    @price_groups = PriceGroup.find(:all,
      :conditions => ["price_groups.source_id IS NOT NULL AND price_groups.source_id != ? AND variants.product_id = ?",
                      product.supplier.price_source_id, product.id],
      :include => [:variants, :price_entries])

    @all_minimums = (@price_groups.collect { |g| g.price_entries.collect { |e| e.minimum } }.flatten + @minimums).sort.uniq
  end

  attr_reader :supplier_groups, :price_groups, :all_minimums
end

class PriceCollectionCompetition < PriceCollectionAll 
  attr_reader :price_bounds
  
  PriceNode = Struct.new :minimum, :marginal, :groups
  CurveParams = Struct.new :coef, :exp

  def initialize(product, count = nil)
    super product, count
    @product = product
  end
    
  def default_price(cost_group, params)
    #m1, m2, pmax1 = nil, pmin1 = nil)
    raise "m1 needed" unless m1 = params[:m1]
    raise "m2 needed" unless m2 = params[:m2]
    pmax1 = params[:pmax1]
    pmin1 = params[:pmin1]    

    # Base costs
    cost_entries = cost_group.price_entries.to_a
    cost_first = cost_entries.find { |e| e.marginal and e.fixed.to_i == 0 }
    cost_last = cost_entries.reverse.find { |e| e.marginal }

    n1 = supplier_minimums.first
    n1 = minimums.find { |m| m > n1 } || 12 if n1 == 1
    n1 = params[:n1] unless n1
    raise "No n1: #{supplier_minimums.inspect} #{minimums.inspect}" unless n1
    if params[:n2] and params[:n2] != n1
      n2 = params[:n2]
    else
      n2 = supplier_minimums.last
      if supplier_minimums.size <= 2
        n2 = [(2.029*n1**1.585).to_i, n2, 5].max
      end
      n2 *= 2 while n2 < 5*n1
    end

    puts "N1: #{n1}  N2: #{n2}"
    
    if pmax1 or pmin1
      n0 = minimums.first || 0
#      cost_f = cost_first.marginal * [100, n1].min + cost_first.fixed
      cost_f = cost_first.marginal * (n0 > 25 ? n0 : n1) + cost_first.fixed
#      cost_l = cost_last.marginal * n1 + cost_last.fixed
#      raise "Cost backwards #{cost_f} < #{cost_l}" if cost_f < cost_l
      if pmax1 and n0 <= 50
        mp1 = (cost_f + pmax1).to_f / cost_f.to_f
        if mp1 < m1
          puts " Margin Lowered: #{m1} => #{mp1}"
          if m2 > mp1
            m2 = [(mp1 - 1.0) / (m1 - 1.0) * (m2 - 1.0) + 1.0,
                  (mp1 - 1.0)*0.75 + 1.0].max
          end
          m1 = mp1 
        end
      end

      if pmin1
        mp1 = (cost_f + pmin1).to_f / cost_f.to_f
        if mp1 > m1
          puts " Margin Raised: #{m1} => #{mp1}"
          # m1 for -1 exponent = (m2 - 1.0) * (n2.to_f / n1.to_f) + 1.0
          m1max = (m2 - 1.0) * (n2.to_f / n1.to_f) + 1.0
          m1 = (mp1 < m1max) ? mp1 : ((m1max - m1) * 0.80 + m1)
        end
      end

      raise "Backwardized: #{m1} < #{m2} #{n1} #{n2}" if m1 < m2
    end

    raise "Below Cost" if m1 <= 1.0 or m2 <= 1.0

    # Derived Constants
    exp = Math.log((m2 - 1.0)/(m1 - 1.0))/Math.log((n2).to_f/(n1).to_f)
    const = (m1 - 1.0)/(n1)**exp

    puts " Default: #{m1} @ #{n1}  :  #{m2} @ #{n2}  =  #{const} ^ #{exp}"
    
    CurveParams.new((cost_last.marginal * const).round_cents, exp)
  end
  
  def low_price_nodes(groups)
    minimum = cost_groups.collect { |g| g.price_entries.to_a.find { |e| e.fixed.to_i == 0 }.minimum }.max

    # Determine Lowest price @ each min
    price_hash = {}
    groups.each do |group|
      group.price_entries.each do |entry|  
        next if entry.marginal.nil? or entry.minimum < minimum
        if !price_hash[entry.minimum] or
            price_hash[entry.minimum].marginal > entry.marginal
          price_hash[entry.minimum] = PriceNode.new entry.minimum, entry.marginal, [group]
        end
      end
    end

#    low_price = []
#    price_hash.to_a.sort_by { |(k, v)| k }.each do |min, pn|
#      low_price << pn if low_price.empty? or low_price.last.marginal > pn.marginal
#    end

    low_price = price_hash.to_a.sort_by { |(k, v)| k }.collect { |min, pn| pn }

    
    # Adjust for cost basis
    cost_group = cost_groups.first
    low_price.first.minimum = cost_group.price_entries.first.minimum if low_price.first and low_price.first.minimum < cost_group.price_entries.first.minimum
    
    min_marginal_cost = cost_group.price_entries.reverse.find { |e| !e.marginal.nil? }.marginal
    low_price.each do |lp|
      entry = cost_group.price_entries.reverse.find { |e| e.minimum <= lp.minimum and !e.marginal.nil? }
      next unless entry
      lp.marginal = lp.marginal - ((entry.marginal + entry.fixed / lp.minimum) - min_marginal_cost)
    end
    
    max_n = cost_group.price_entries.last.minimum * (2.5 / 1.5)
    low_price.delete_if { |n| n.minimum > max_n }
    
    short_list = []
    low_price.each do |lp|
      short_list << lp if short_list.empty? or short_list.last.marginal > lp.marginal
    end

#    puts "Short: #{short_list.inspect}"

    return short_list
  end
  
  def low_price_max
    list = low_price_nodes(supplier_groups)
    
  end
  
  def fit_curve_to_nodes(low_price, discount = 0.97)
    require 'gsl'
    puts "Low: " + low_price.collect { |pn| "#{pn.marginal} @ #{pn.minimum}" }.join(', ')
    min_marginal_cost = cost_groups.first.price_entries.reverse.find { |e| !e.marginal.nil? }.marginal
        
    mins = low_price.collect { |n| n.minimum }
    x = mins + [1e+100]
    w = low_price.collect { |n| Math.log(n.minimum/mins.first) + 2.0 } + [1e+6]
    y = low_price.collect { |n| (n.marginal * discount).to_f } + [min_marginal_cost.to_f]
    
    # Fitting
    guess = [min_marginal_cost, 18.0, -0.3]
    coef, err, chi2, dof = GSL::MultiFit::FdfSolver.fit(GSL::Vector.alloc(x), GSL::Vector.alloc(w), GSL::Vector.alloc(y), "power", guess)
    
    puts "Params: #{coef[1]} #{coef[2]}"
    CurveParams.new(Money.new(coef[1].to_f).round_cents, coef[2])
  end
  
  def curve_exp(a, b)
    Math::E ** (Math.log(a.coef.to_f/b.coef.to_f)/(b.exp - a.exp))
  end
  
  def curve_intersect(a, b)
    n = curve_exp(a, b)
    return n if n > supplier_minimums.first and n < all_minimums.last
    nil
  end
  
  def curve_above(a, b)
    a.coef*(supplier_minimums.first**a.exp) > b.coef*(supplier_minimums.first**b.exp)
  end
  
  def competative_price(cost_group, supplier_group, price_params = {})     
    paramDefault = default_price(cost_group, { :m1 => 1.65, :m2 => 1.35, :pmax1 => PriceSet::required_profit * 3.5 }.merge(price_params)) #, PriceSet::required_profit*0.8)
    @price_bounds << PriceSet.new(cost_group, paramDefault.coef, paramDefault.exp, @count)
    
    paramMin = paramMax = nil
    groups = price_groups.dup
    until groups.empty?
      price_nodes = low_price_nodes(groups)
      break if price_nodes.length < 2
      paramComp = fit_curve_to_nodes(price_nodes)

      unless paramMin
        puts "Calculate MIN"
        paramMin = default_price(cost_group, { :m1 => 1.50, :m2 => 1.20, :pmax1 => PriceSet::required_profit * 1.5 })
        @price_bounds << PriceSet.new(cost_group, paramMin.coef, paramMin.exp, @count)
      end

      min_intersect = curve_intersect(paramComp, paramMin)
      min_above = curve_above(paramComp, paramMin)
      puts "Iter: #{min_intersect.inspect} #{min_above.inspect}"
      if !min_intersect and min_above
        unless paramMax
          puts "Calculate MAX"
          paramMax = if price_nodes = low_price_nodes([supplier_group]) and price_nodes.length > 2
                       fit_curve_to_nodes(price_nodes, 0.9)
                     else
                       default_price(cost_group, { :m1 => 2.4, :m2 => 1.6 })
                     end 
          @price_bounds << PriceSet.new(cost_group, paramMax.coef, paramMax.exp, @count)
        end

        # Above Minimum threshold
        max_intersect = curve_intersect(paramMax, paramComp)
        if !max_intersect and
            curve_above(paramMax, paramComp)
          @competitors = price_nodes.collect { |n| n.groups.collect { |g| g.source.name } }.flatten.uniq
          puts "Competitors: #{@competitors.inspect}"
          return paramComp # Use competative pricing within bounds
        else
          puts "Overpriced #{max_intersect.inspect} #{min_intersect.inspect} #{min_above.inspect}"
          break # Competative is overprices go to default
      end else
        # Prune groups and run again
        remove_node = nil
        remove_node = price_nodes.find { |p| p.minimum >= min_intersect } if min_intersect
        remove_node = price_nodes.first unless remove_node
        groups -= remove_node.groups
      end
    end

    # Remove default pricing bound
    @price_bounds.shift
    
    return paramDefault
  end
  
  def margin(param, cost, n)
    profit = param.coef * (n ** param.exp)
    profit / (cost + profit)
  end

  def margin_pair(cost_group, supplier_group, param)
    cost = cost_group.price_entries.reverse.find { |e| !e.marginal.nil? }.marginal
    min = supplier_group.price_entries.find { |e| !e.marginal.nil? }.minimum
    max = supplier_group.price_entries.reverse.find { |e| !e.marginal.nil? }.minimum
    [margin(param, cost, min), margin(param, cost, max)]
  end

  def calculate_price(price_params = {})
    @price_bounds = []
    
    @price_sets = @cost_groups.zip(@supplier_groups).collect do |cost_group, supplier_group|
      param = competative_price(cost_group, supplier_group, price_params)
      if param.exp < -1.0 or param.exp >= 0.0
        puts " OVERRIDE INVALID PRICE: #{param.inspect}"
        param.exp = 0.0
        param.coef = Money.new(0.01)
      end
      if (cost_group.coefficient.to_f != param.coef.to_f) or
          ((cost_group.exponent.to_f - param.exp.to_f).abs > 1e-14)
#        prev = margin_pair(cost_group, supplier_group, CurveParams.new(Money.new((cost_group.coefficient*100.0).to_i), cost_group.exponent))
#        curr = margin_pair(cost_group, supplier_group, param)
#        puts "Price Change #{@product.id} #{cost_group.id}: #{prev.inspect} => #{curr.inspect}"
        puts " * Price Change:  #{cost_group.coefficient.inspect} ^ #{cost_group.exponent.inspect} => #{param.coef.inspect} ^ #{param.exp.inspect}"
        cost_group.coefficient = param.coef
        cost_group.exponent = param.exp
        cost_group.save!
      end
      PriceSet.new(cost_group, param.coef, param.exp, @count)
    end

    adjust_to_profit!

    # Min max shown on category pages
    max_cache = @price_sets.collect do |set|
      set.price_at_minimum
    end.compact.max
    @product.price_max_cache = max_cache && max_cache.round_cents

    min_cache = @price_sets.collect do |set|
      set.price_at_maximum
    end.compact.min
    @product.price_min_cache = min_cache && min_cache.round_cents

    # price_comp_cache for google base price
    technique = @product.decorations.collect { |d| d.technique }.uniq.sort.first
    dec_price_group = technique && technique.price_groups.find_by_supplier_id(@product.supplier_id, :include => :entries)
    limit = technique.decorations.find_all_by_product_id(@product.id).collect { |d| d.limit }.compact.max if technique
#    comp_cache = @price_sets.collect do |set|
#      price = set.price_at_competative
#
#      if price and dec_price_group
#        qty = set.breaks.first.minimum
#        dec_price = dec_price_group.pricing(1, limit, qty).price
#        price += dec_price.fixed + dec_price.marginal * qty
#      end
#
#      price
#    end.compact.min
#    @product.price_comp_cache = comp_cache && comp_cache.round_cents

    @product.price_fullstring_cache = minimums.collect { |n| (min = price_range(n).min) ? "#{n}: #{min.to_perty}" : nil }.compact.join(', ')
    normal_minimum = @price_sets.collect do |set|
      set.normal_minimum
    end.compact.min
    normal_price = price_range(normal_minimum).min
    @product.price_shortstring_cache = normal_price && "#{normal_minimum}: #{normal_price.to_perty}"[0...12]
    @product.price_comp_cache = (normal_price * normal_minimum).round_cents if normal_price

    @product.save!
  end
end


#class ProductCategoriesSweeper < ActionController::Caching::Sweeper
##    include Singleton
#    observe Product
#    
#  @@perform_caching = true
#  
#  def after_add(product, category)
##    puts "ADD *************88 #{perform_caching.inspect}"
##    perform_caching = true
#
#    category.path_obj_list.each do |cat|
#      path = cat.path_web
##      path += '/name/1' unless cat.children
#      ret = expire_page({ :controller => 'categories', :action => 'main', :path => path })
##      puts "RET: #{path} -> #{ret}"
#    end
#    
#    ret = expire_page({ :controller => 'categories', :action => 'main', :path => '' })
##    puts "Last: #{path} -> #{ret}"
#  end
#
#  def after_remove(product, category)
##    puts "REMOVE *************88"
#  end
#end

class Product < ActiveRecord::Base
  has_many :decorations, :conditions => 'NOT(deleted)'
  belongs_to :supplier
  belongs_to :featured, :class_name => 'Category', :foreign_key => 'featured_id'
#  has_and_belongs_to_many :categories, {
#    :before_remove => :remove_featured_if,
#    :after_remove => Proc.new { |product, cat| Category.find_by_id(cat.id).destroy_conditional }
#  }
  has_many :category_products
  has_many :categories, :through => :category_products, :before_remove => :remove_featured_if, :after_remove => Proc.new { |product, cat| Category.find_by_id(cat.id).destroy_conditional }

  has_many :tags
  has_many :variants, :conditions => 'NOT(variants.deleted)'
  
  has_many :page_products

  has_many :product_images, :order => 'tag DESC, id'
 
  composed_of :price_min_cache, :class_name => 'Money', :mapping => %w(price_min_cache units), :allow_nil => true
  composed_of :price_comp_cache, :class_name => 'Money', :mapping => %w(price_comp_cache units), :allow_nil => true
  composed_of :price_max_cache, :class_name => 'Money', :mapping => %w(price_max_cache units), :allow_nil => true
  
  serialize :data
  
  before_destroy :cascade_destroy
  def cascade_destroy
    # Prevent foreign key violation if this causes category delete
    if self['featured_id']
      self['featured_id'] = nil
      save!
    end
    
    tags.each { |tag| tag.destroy }
    decorations.each { |decoration| decoration.destroy }
    variants.each { |variant| variant.destroy }
  end
  
  # For tsearch (part of PostgreSQL)
#  acts_as_tsearch :vectors => {
#    :locale => "english",
#    :fields => {
#      "a" => {:columns => ['products.supplier_num', 'products.name'], :weight => 1.0},
#      "b" => {:columns => ['properties.property_string', 'suppliers.name', 'categories.category_string'], :weight => 0.6},
#      "c" => {:columns => ['products.description'], :weight => 0.4}
#    },
#    :tables => {
#      :properties => {
#        :from => "(SELECT products.id as prod_id, array_to_string(array(" + 
#                    "SELECT value FROM properties JOIN properties_variants ON properties.id = properties_variants.property_id " +
#                    "JOIN variants ON properties_variants.variant_id = variants.id " +
#                    "WHERE variants.product_id = products.id " +
#                    "ORDER BY properties.name" +
#                  "), ' ') as property_string " +
#                  "FROM products) AS properties, " +
#                 "suppliers, " +
#                 "(SELECT products.id as prod_id, array_to_string(array(" + 
#                    "SELECT name FROM categories JOIN categories_products ON# categories.id = categories_products.category_id " +
#                    "WHERE categories_products.product_id = products.id " +
#                  "), ' ') as category_string " +
#                  "FROM products) AS categories ",
#        :where => 'properties.prod_id = products.id AND suppliers.id = products.supplier_id AND categories.prod_id = products.id'
#      }
#    }
#  }

  include PgSearch
  pg_search_scope :search,
    :against => { :supplier_num => 'A', :name => 'A', :description => 'C' },
    :associated_against => { :categories => { :name => 'B' }, :supplier => { :name => 'B' } },
    :using => { :tsearch => { :dictionary => "english" } }

  def property_group_names
    property_groups.flatten.find_all { |n| !Property.is_image?(n) }
  end

  def web_id
    "#{id}-#{URI.encode(name.gsub(/ +|\//, '-').gsub(/[^A-Z0-9_]/i,'-'))}"
  end
       
  def tag_names
    tags.collect { |t| t.name }.join(' ')
  end
  
  def supplier_name
    supplier.name
  end
  
  def variants_supplier_num
    variants.collect { |v| v.supplier_num }.join(' ')
  end
  
  def decoration_locations
    decorations.collect { |d| d.location }.uniq.join(' ')
  end
  
  def decoration_techniques
    DecorationTechnique.find(:all,
      :conditions => "product_id = #{id}",
      :include => :decorations).collect { |t| t.name }.join(' ')
  end
    
  def calc_properties
    properties = {}
    properties.default = []
    variants.each do |variant|
      variant.properties.each do |property|
        properties[property] += [variant]
      end
    end
    @common_properties = properties.collect do |k, v| 
      k if v.size == variants.size
    end.compact  
    
    @common_properties.each { |p| properties.delete(p) }

    # Transform property to array representation
    properties = properties.each_with_object({}) do |(prop, list), hash|
      hash[[prop.name, prop.value]] = list
    end
    properties.default = []
    
    property_map = {}
    property_map.default = []
    properties.keys.each { |name, value| property_map[name] += [value] }

    # Find all pairs of properties that don't have a variant
    merge_combos = property_map.keys.combination(2).select do |a_name, b_name|
      property_map[a_name].find do |a_value|
        property_map[b_name].find do |b_value|
          next true if (properties[[a_name, a_value]] & properties[[b_name, b_value]]).empty?
        end
      end
    end

    # Merge common pairs
    merge_groups = []
    until merge_combos.empty?
      a_pair = merge_combos.shift
      m = merge_combos.select { |b_pair| !(a_pair & b_pair).empty? }
      if m.empty?
        merge_groups << a_pair
      else
        merge_combos -= m
        merge_combos.unshift (a_pair + m.flatten).uniq
      end
    end

    @property_groups = (property_map.keys - merge_groups.flatten).collect { |n| [n] } + merge_groups
  end
  
  def common_properties
    calc_properties unless @common_properties
    return @common_properties
  end
  
  def property_groups
    calc_properties unless @property_groups
    return @property_groups
  end
  
  def properties_get
    return @properties_get if @properties_get
    @properties_get = Property.find(:all, :conditions =>
      ["id IN " +
       "(SELECT property_id FROM properties_variants JOIN variants ON properties_variants.variant_id = variants.id WHERE variants.product_id = ?)",
      id]
    ).inject({}) { |h, p| h[p.name] = (h[p.name] || []) + [p.translate]; h }
  end

  @@variant_sort_order = { 'size' => %w(XS S M L XL XXL 3X 4X 5X) }

  def variant_properties   
    property_groups.collect do |names|
      [names, variants.collect do |variant|
        [names.collect do |name|
           variant.properties.to_a.find { |p| p.name == name }
         end, variant]
       end.group_by(&:first).collect do |properties, list|
         [properties, list.collect { |e| e.last }]
       end.sort_by do |n, vars|
         next [] unless n.compact.first && v = n.compact.first.translate
         if order = @@variant_sort_order[n.compact.first.name]
           res = [order.index(v) || 100]
         else
           res = v.split(/(\d+)/).collect do |s|
             next if s.empty?
             i = s.to_i
             next i if i.to_s == s
             s
           end.compact
           class << res # Kludge to handle non comparable arrays (int vs str)
             def <=>(a)
               super(a) || -1
             end
           end
         end
         res
       end]
    end.sort_by { |n| n.first }
  end
  
  def remove_featured_if(category)
    if self['featured_id'] == category.id
      self['featured_id'] = nil
      save!
    end
  end
 
#  put in Supplier get_product 
  def set_quickbooks
    # Prevent from being added to quickbooks until used by order_item
    self.quickbooks_id = 'BLOCKED' unless quickbooks_id
  end
  before_create :set_quickbooks

  def delete
    # Remove from all categories
    categories.clear
    self['featured_id'] = nil
    self['deleted'] = true
    save!
  end
  
  # For importing data
  def get_variant(num)
    var = Variant.find(:first, :conditions => {
      :product_id => id,
      :supplier_num => num
    })
    
    if var
      var.association(:product).target = self
      var.deleted = false
    else
      var = Variant.new({
        :product => self,
        :supplier_num => num
      }) unless var
    end
    var
  end
    
  def self.print_records_two(deleted, created, modified = [])
    arr = deleted+created+modified
    columns = arr.first.class.column_names    
    widths = columns.collect { |column| ([column.size] + arr.collect { |rec| rec[column].to_s.size }).max }
    
    str = "\n     " + columns.zip(widths).collect { |column, width| column.ljust(width) }.join(' ')
    str << "\n   " + [[deleted, '-'], [created, '+'], [modified, '|']].collect do |list, sign|
      list.collect do |rec|
        sign + ' ' + columns.zip(widths).collect { |column, width| rec[column].to_s.ljust(width) }.join(' ')
      end
    end.flatten.compact.join("\n   ") + "\n"
  end

  def valid_variant_images?
    variants.includes(:product_images).where('product_images.id IS NULL').empty?
  end

  def set_images(images)
    str = ''
    all = product_images.to_a
    
    [images].flatten.compact.each do |img|
      if pi = all.find { |pi| pi.supplier_ref == img.id }
        unless pi.variants.empty?
          str << "   | Image: #{img.id} - all variants\n"
          pi.variants.delete_all
        end

        if pi.tag != img.tag
          str << "  | Tag: #{pi.tag} => #{img.tag}\n"
          pi.tag = img.tag
          pi.save!
        end
      else
        str << "   + Image: #{img.id}\n"
        pi = product_images.create(:supplier_ref => img.id,
                                   :image => img.get,
                                   :tag => img.tag)
        begin
          pi.image.reprocess!
        rescue Errno::ENOENT => e
          raise "Most likely #{img.path} is bad"
        end
        pi.image.save
      end
    end

    str
  end

  def delete_images_except(images)
    str = ''
    
    images = [images].flatten.compact
    product_images.to_a.each do |pi|
      unless images.find { |i| i.id == pi.supplier_ref }
        str << "   - Image: #{pi.supplier_ref}\n"
        pi.destroy
      end
    end
    
    str
  end
  
  def set_categories(dst)
    src = categories.collect { |c| Category.find_by_id(c.id) }
    added = []
    
    dst.uniq.each do |d|
      if match = src.find { |s| s.matches?(d) }
        src.delete(match)
      else
        category = Category.get(d)
        categories << category
        added << category
      end
    end

    str = ''

    src.delete_if do |s|
      if CategoryProduct.where(:category_id => s.id, :product_id => id, :pinned => true).exists?
        str << "   * #{s.path}\n"
        next true
      end
      false
    end
    
    src.each do |s|
      if self['featured_id'] == s.id
        self['featured_id'] = nil
        save!
      end
      categories.delete(s)
    end
    
    src.each { |deleted| str << "   - #{deleted.path}\n" }
    added.each { |add| str << "   + #{add.path} (#{add.id})\n"}
    
#    assign_to_featured unless str.empty?
    
    str
  end
  
  def set_tags(dst)
    src = tags.find(:all)
    added = []
    
    dst.each do |d|
      if match = src.find { |s| s.name == d }
        src.delete(match)
      else
        tag = Tag.create({:name => d, :product => self})
        added << tag
      end
    end
    
    src.each do |s|
      s.destroy
    end
    
    (src.empty? and added.empty?) ? '' : "  Tags: #{Product.print_records_two(src, added)}"
  end

  def set_decorations(dst)
    src = decorations.find(:all, :include => :technique) 
    create = []
    
    dst.each do |d|
      if match = src.find { |s| d == s }
        src.delete(match)
      else
        create << d
      end
    end
    
    modified = []
    
    src.each do |s|
      if d = create.find { |c| c.technique_record == s.technique }
        # Recycle old decoration
        s.update_attributes(d.to_hash)
        modified << s
        create.delete(d)
      else
        # This destroy can fail if it is referenced from order_item_decorations
        # Hopefully the recycle will address the problem most of the time.
        # Is a recycle really acceptable?
        if s.order_item_decorations.empty?
          s.destroy
        else
          s.deleted = true
          s.save!
        end
      end
    end

    src -= modified
    
    # Create remaining
    created = create.collect { |d| decorations.create(d.to_hash) }
    
    (src + created + modified).empty? ? '' : "  Decoration: #{Product.print_records_two(src, created, modified)}"
  end
  
  # source_id: Price Source ID
  # dst: list of [price list, variant records]
  #  price list: list of hash { :marginal, :fixed, :minimum }
  #  variant records: list of Variant
  def set_prices(source, dst)
    all_records = dst.collect { |price, records| records }.flatten
    raise "Duplicate Records in set_prices: #{all_records.inspect}" unless all_records.length == all_records.uniq.length

    product_log = ''
    src = PriceGroup.find(:all,
      :conditions => {
        'variants.product_id' => id,
        'price_groups.source_id' => source && source.id
      },
      :include => :variants)
    
    combinations = []
    
    # Establish match for all src dst combinations
    src.each do |src_group|
      dst.each do |dst_data, dst_variants|
        src_only = []
        dst_only = dst_variants.dup
        src_group.variants.each do |src_variant|
          src_only << src_variant unless dst_only.delete(src_variant)
        end
        combinations << [src_only, dst_only, src_group, dst_data]
      end
    end

    # Remove all but the closest matches
    matches = []
    combinations.sort! { |l, r| (l[0].length + l[1].length) <=> (r[0].length + r[1].length) }
    while lst = combinations.shift
      matches << lst
      src_only, dst_only, src_group, dst_data = lst
      combinations.delete_if { |a, b, s, d| (src_group == s) or (dst_data == d) }
    end

    matches.each do |src_only, dst_only, src_group, dst_data|
      src.delete(src_group)
      dst.delete_if { |d| d.first == dst_data }
      
      diff_prices = src_group.diff_prices(dst_data)

      next unless diff_prices or !src_only.empty? or !dst_only.empty?

      product_log << "  #{source ? source.name : 'Cost'} Changed: "
      product_log << "-(" + src_only.collect { |s| s.supplier_num }.join(',') + ") " unless src_only.empty?
      product_log << "+(" + dst_only.collect { |s| s.supplier_num }.join(',') + ")" unless dst_only.empty?
      product_log << "\n"
      
      src_group.variants.delete(src_only)
      src_group.variants << dst_only
      
      if diff_prices
        product_log << "   - #{src_group.print_prices}\n"
        src_group.update_prices(dst_data)
        product_log << "   + #{src_group.print_prices}\n"
      end
    end
    
    # Add new groups
    dst.each do |dst_data, dst_variants|
      group = PriceGroup.create_prices(dst_data, source && source.id)
      group.variants = dst_variants
      
      product_log << "  #{source ? source.name : 'Cost'} Added: \n"
      product_log << "    (" + dst_variants.collect { |s| s.supplier_num }.join(',') + ")\n"
      product_log << "    + #{group.print_prices}\n"
    end
    
    # Remove unused groups
    src.each do |group|
      group.variants.delete_all
      group.destroy if destroy = group.order_items.empty?

      product_log << "  #{source ? source.name : 'Cost'} #{destroy ? 'Removed' : 'Revoked'} \n"
      product_log << "    (" + group.variants.collect { |s| s.supplier_num }.join(',') + ")\n"
      product_log << "    - #{group.print_prices}\n"
    end
    product_log
  end
  
  def supplier_url
    replace = {
      'supplier_num' => supplier_num,
      'data_id' => data && data[:id],
      'data_url' => data && data[:url]
    }
    unless supplier.web.blank?
      'http://' + supplier.web.split(/#\{(\w+?)\}/).collect do |part|
        replace[part] || part
      end.join
    else
      nil
    end
  end
end

