module WillPaginate
  module Finder
    module ClassMethods
      def paginate_by_sql(sql, options)
        WillPaginate::Collection.create(*wp_parse_options(options)) do |pager|
          query = sanitize_sql(sql.dup)
          original_query = query.dup
          # add limit, offset
          query << " LIMIT #{pager.per_page}"
          query << " OFFSET #{pager.offset}"
#          add_limit! query, :offset => pager.offset, :limit => pager.per_page
          # perfom the find
          pager.replace find_by_sql(query)
          
          unless pager.total_entries
            count_query = original_query.sub /\bORDER\s+BY\s+[\w`,\s]+$/mi, ''
            count_query = "SELECT COUNT(*) FROM (#{count_query})"
            
            unless self.connection.adapter_name =~ /^(oracle|oci$)/i
              count_query << ' AS count_table'
            end
            # perform the count query
            pager.total_entries = count_by_sql(count_query)
          end
        end
      end
    end
  end
end
        

class Category < ActiveRecord::Base
  attr_accessible :lft, :rgt, :name, :parent, :parent_id
  acts_as_nested_set
  
  has_many :category_products
  has_many :products, :through => :category_products

  has_and_belongs_to_many :keywords
  has_many :featured, :class_name => 'Product', :foreign_key => 'featured_id'

  attr_accessible :description, :google_category
  
  after_create :invalidate_cache
  after_destroy :invalidate_cache
  after_update :invalidate_cache
  def invalidate_cache
    self.class.reload
  end
  
#  acts_as_tsearch :vectors => {
#    :locale => "english",
#    :fields => [:name]
#  }

  include PgSearch
  pg_search_scope :search, :against => :name,
  :using => { :tsearch => { :dictionary => "english" } }
  
  def destroy_conditional
    return nil unless products.count == 0
    return nil unless !children or children.size == 0
    
    # Cleanup featured
    featured.find(:all).each do |product|
      product.featured_id = nil
      product.save!
    end
    
    destroy
    
    @@id_map.delete(id)
    parent.children.delete(self)

    parent.destroy_conditional
    true
  end

private
  def self.children_recursive_private(hash, current)
    current.association(:children).target = hash[current.id]
    hash[current.id].each do |child|
      children_recursive_private(hash, child) if hash.has_key?(child.id)
      child.association(:parent).target = current
    end
  end

public
  @@root = nil
  @@id_map = {}

  def self.refresh
    return unless @@root

    root = Category.find(1)
    if root.updated_at != @@root.updated_at || root.rgt != @@root.rgt
      reload
    end
  end

  def self.reload
    @@root = nil
    @@id_map = {}
    root
  end

  def self.root
    return @@root if @@root

    logger.info("Loading Categories")

    @@root = Category.find_by_name('root')
    
    by_parent_id = {}
    by_parent_id.default = []
      
    @@id_map[@@root.id] = @@root
      
    @@root.descendants.each do |record|
      @@id_map[record.id] = record
      by_parent_id[record[record.parent_column_name]] += [record]
    end
      
    children_recursive_private(by_parent_id, @@root)

    @@root
  end
  
  def self.all
    root
    @@id_map.values
  end
  
  def self.find_by_id(id)
    root
    res = @@id_map[id.to_i]
    raise "COULDN'T FIND: #{id}" unless res
    res
  end
  
   
#  def self.new_find_by_path(list, parent_id = 1)
#    rec = find(:first, :conditions => ["name = ? AND parent_id = ?", list.first, parent_id])
#    return nil unless rec
#    return rec if list.size == 1
#    new_find_by_path(list[1..-1], rec.id)
#  end
#  
#  def matches?(list)
##    puts "Match: #{list.inspect}"
#    rec = self.class.new_find_by_path(list)
##    puts "Rec: #{rec.inspect} == #{self.inspect}"
#    return nil unless rec
#    return rec.id == self.id
#  end
  
  def matches?(list)
    path_name_list == list
  end
  
  # REMOVE!!!
  def path_name_list
    parent ? (((parent_id != self.class.root.id) ? parent.path_name_list : []) + [name]) : []
  end
  
  def path
    path_name_list.join('/')
  end
  
  def path_web
#    path_name_list.collect { |c| c + '/'}.join.tr(' ','_')
#    path_name_list.join('/').tr(' ','_')
    path_name_list.collect { |c| c.tr(' ','_') }    
  end
  
  def path_obj_list
    ((parent and parent_id != self.class.root.id) ? parent.path_obj_list : []) + [self]
  end
 
  def self.find_by_path(path)
    current = root
    path.each do |comp|
      current = current.children.to_a.find { |child| child.name == comp }
      return nil unless current
    end
    current
  end
  
  def base
    return nil if self == @@root
    ret = (parent_id == self.class.root.id) ? self : parent.base
    ret
  end
  
  def in_path(cat)
    return false if self == @@root
    return true if cat == self
    (parent_id == self.class.root.id) ? false : parent.in_path(cat)
  end
    
  def all_condition
    "(#{left_column_name} >= #{self[left_column_name]}) and (#{right_column_name} <= #{self[right_column_name]})"
  end 
  
  def count_products(options = {})
    if options[:tag]
      Product.count(:all,
        :conditions => "tags.name = '#{options[:tag]}' AND " + (options[:children] ? all_condition : "category_id = #{id}"),
        :include => [:categories, :tags])
    else
      if options[:children]
        Category.where(all_condition).joins("JOIN categories_products ON categories.id = categories_products.category_id").select('DISTINCT product_id').count
      else
        Product.count(:all,
                      :conditions => ("category_id = #{id}"),
                      :joins => :categories)
      end
    end
  end
  
  @@order_mapping = { 
    'name' => 'products.name, products.price_min_cache',
    'price' => 'products.price_min_cache, products.name' }
    
  def self.order_list
    @@order_mapping.keys
  end
  
  def self.valid_order?(order)
    @@order_mapping.has_key?(order)
  end
  
  def find_products_sql(options)
    sql =  "SELECT DISTINCT products.* "
    if options[:tag]
      sql << "FROM tags LEFT OUTER JOIN products ON products.id = tags.product_id "
    else
      sql << "FROM products "
    end
    sql << "LEFT OUTER JOIN categories_products ON categories_products.product_id = products.id "
    sql << "LEFT OUTER JOIN categories ON categories_products.category_id = categories.id "
    if options[:tag]
      sql << "WHERE tags.name = #{connection.quote(options[:tag])} AND "
    else
      sql << "WHERE " 
    end
    sql << (options[:children] ? all_condition : "category_id = #{id}")
    if options[:conditions]
      sql << " AND (#{options[:conditions]})"
    end
    order_sql = @@order_mapping[options[:sort]]
    order_sql = order_sql.split(',').collect { |sub| sub + ' DESC'}.join(',') if options[:desc]
    sql << " ORDER BY #{order_sql} " if options[:sort]
    sql
  end

  # Temporary Kludge
  private
  def sanitize_limit(limit)
    if limit.is_a?(Integer) || limit.is_a?(Arel::Nodes::SqlLiteral)
      limit
    elsif limit.to_s =~ /,/
      Arel.sql limit.to_s.split(',').map{ |i| Integer(i) }.join(',')
    else
      Integer(limit)
    end
  end

  def add_limit_offset!(sql, options)
    if limit = options[:limit]
      sql << " LIMIT #{sanitize_limit(limit)}"
    end
    if offset = options[:offset]
      sql << " OFFSET #{offset.to_i}"
    end
    sql
  end
  public
      
  def find_products(options)
    sql = find_products_sql(options)
    add_limit_offset!(sql, options)
    
    Product.find_by_sql(sql)
  end

  def paginate_products(options)
    sql = find_products_sql(options)
    Product.paginate_by_sql(sql, options)
  end
  
  # The +15 is to mitigate a bug if a series of products have the same price
  def find_products_in_window(product, options)
    limit = options[:limit]
    
    compare_column = @@order_mapping[options[:sort]].split(',').first.gsub('products.','')
  
    left_sql = find_products_sql(options.merge({:conditions =>
      "products.#{compare_column} <= #{connection.quote(product[compare_column])}",
      :sort => options[:sort],
      :desc => true}))
    add_limit_offset!(left_sql, {:limit => limit+15, :offset => 0})
    left_list = Product.find_by_sql(left_sql)
    return nil unless idx = left_list.index(product)
    left_list = left_list[(idx+1)..-1] unless left_list.empty?
    
    right_sql = find_products_sql(options.merge({:conditions =>
      "products.#{compare_column} >= #{connection.quote(product[compare_column])}",
      :sort => options[:sort]}))
    add_limit_offset!(right_sql, {:limit => limit+15, :offset => 0})
    right_list = Product.find_by_sql(right_sql)
    return nil unless idx = right_list.index(product)
    right_list = right_list[(idx+1)..-1] unless right_list.empty?
    
    if left_list.size >= right_list.size
      right_list = right_list.slice(0,limit/2)
      left_list = left_list.slice(0,limit-right_list.size-1)
    else
      left_list = left_list.slice(0,limit/2)
      right_list = right_list.slice(0,limit-left_list.size-1)
    end
    
    left_list.reverse + [product] + right_list
  end

private
  def create_temp_sequence(initial)
    unless connection.instance_variable_get('@sequence_counter_created')
      command = "create temporary sequence counter"
      logger.info("Executing: #{command}")
      connection.execute(command)
      connection.instance_variable_set('@sequence_counter_created', true)
    end
    connection.execute("SELECT setval('counter',#{initial})")
  end    

  def find_products_sql_with_count!(options)
    sql = "(SELECT nextval('counter') as counter, products.* FROM ("
    sql << find_products_sql(options.merge({:sort => "price"}))
    sql << ") AS products)"
    sql
  end

public  
  # Dependant on counter creation
  def calculate_products_price_breaks(options)
    limit = options[:limit] || options[:per_page] # Kludge fix!!!
    create_temp_sequence(limit-1)

    sql = "SELECT counter/#{limit} AS page, MIN(price_min_cache), MAX(price_min_cache), COUNT(*) FROM "
    sql << find_products_sql_with_count!(options)
    sql << " AS products GROUP BY counter/#{limit} ORDER BY page"
    res = connection.select_all(sql)
    res.delete_if { |r| r['min'].nil? or r['max'].nil? }

    if options[:window] and options[:window] < res.size and !res.empty?
      idx = []
      last = -1
      (0...options[:window]).collect do |x|
        i = (x.to_f/options[:window]*res.size).to_i
        idx << nil if i != last + 1
        idx << i
        last = i
      end
      idx << nil if idx.last != res.size - 1
      
      res = idx.collect { |x| res[x] if x }
    end
    
    res.each { |b| %w(min max).each { |n| b[n] = Money.new(Integer(b[n])) } if b }

    res
  end

  def select_products(options)
    count = count_products(options)
    limit = options[:limit] || options[:per_page] # Kludge fix!!!
    offset = count / (limit+1)
    pos_list = (1..limit).to_a.collect { |i| i*offset }

    create_temp_sequence(1)

    sql = "SELECT products.* FROM "
    sql << find_products_sql_with_count!(options)
    sql << " AS products WHERE counter IN (#{pos_list.join(',')})"

    Product.find_by_sql(sql)
  end
  
  def products_tags(options = {})
    sql =  "SELECT tags.name, COUNT(DISTINCT products.id) as count "
    sql << "FROM tags LEFT OUTER JOIN products ON products.id = tags.product_id "
    sql <<           "LEFT OUTER JOIN categories_products ON categories_products.product_id = products.id "
    sql <<           "LEFT OUTER JOIN categories ON categories_products.category_id = categories.id "    
    sql << ("WHERE " + (options[:children] ? all_condition : "category_id = #{id}"))
    sql << " GROUP BY tags.name "
    sql << "ORDER BY tags.name"
    
    Tag.find_by_sql(sql)
  end
  
  def products_featured(options = {})
    include_children = options.delete(:children)
    options = options.merge({
      :conditions => "featured_id = #{id}",
      :offset => include_children ? options[:limit] : 0,
      :order => 'featured_at DESC'
    })
    
    Product.find(:all, options)
  end
    
  def self.get(cat)
    cat = cat.dup
    parent_id = nil
    current = Category.root
   
    until cat.empty?
      break unless current.children
      nxt_cat = current.children.to_a.find { |c| c.name == cat.first }
      break unless nxt_cat
      cat.shift
      current = nxt_cat
    end
    
    cat.each do |sub|
      current = current.children.create(:name => sub)
    end

    reload unless cat.empty?
    
    current
  end
  
private 
  after_destroy :destroy_parent_if_empty
  def destroy_parent_if_empty
    parent.destroy if parent and parent.children.empty? and parent.pinned != true
  end
end
