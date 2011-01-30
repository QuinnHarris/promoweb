class Bootstrap < ActiveRecord::Migration
  def self.up
    # Admin Users
    create_table :users do |t|
      t.column :login,    :string, :limit => 80, :null => false
      t.column :password, :string, :null => false
    end
    execute "ALTER TABLE users ADD CONSTRAINT login_users UNIQUE(login)"
    User.create({:login => 'quinn', :password => 'Hitachi', :password_confirmation => 'Hitachi' })
    User.create({:login => 'monica', :password => 'robert1', :password_confirmation => 'robert1' })
    
    
    # Price Source
    create_table :price_sources do |t|
      t.column :name, :string, :null => false
      t.column :url,  :string

      t.column :created_at,   :datetime, :null => false
      t.column :updated_at,   :datetime, :null => false
    end
    execute "ALTER TABLE price_sources ADD CONSTRAINT name_price_sources UNIQUE(name)"
    
    # Suppliers
    create_table :suppliers do |t|
      t.column :name,            :string, :limit => 64
      t.column :price_source_id, :integer, :null => false
      
      t.column :web,             :string
      t.column :status,          :string
      t.column :headline,        :string
      t.column :notes,           :text
      
      t.column :created_at,   :datetime, :null => false
      t.column :updated_at,   :datetime, :null => false
    end
    execute "ALTER TABLE suppliers ADD CONSTRAINT name_suppliers UNIQUE(name)"
    
    # Categories
    create_table :categories do |t|
      t.column :parent_id, :integer, :references => :categories
      t.column :lft,       :integer, :null => false
      t.column :rgt,       :integer, :null => false
      t.column :name,      :string, :null => false, :limit => 32
      t.column :updated_at,   :datetime, :null => false
    end
    execute "ALTER TABLE categories ADD CONSTRAINT name_categories UNIQUE(name, parent_id)"
#    execute "ALTER TABLE categories ADD CONSTRAINT lft_categories UNIQUE(lft)"
#    execute "ALTER TABLE categories ADD CONSTRAINT rgt_categories UNIQUE(rgt)"
#    execute "ALTER TABLE categories ADD CHECK (lft <= rgt)"
    
    Category.create({:name=>"root",:lft=>1,:rgt=>2})   

    # Products
    create_table :products do |t|
      t.column :supplier_num, :string, :limit => 32
      t.column :supplier_id,  :integer, :null => false
      t.column :name,         :string, :null => false
      t.column :description,  :text
      t.column :price_min_cache,  :integer
      t.column :price_max_cache,  :integer
      t.column :price_comp_cache,    :integer
      
      t.column :featured_id,  :integer, :references => :categories
      t.column :featured_at,  :datetime
      
      t.column :package_weight,      :float
      t.column :package_units,       :integer
      t.column :package_unit_weight, :float
      t.column :package_height,      :float
      t.column :package_width,       :float
      t.column :package_length,      :float
      
      t.column :created_at,   :datetime, :null => false
      t.column :updated_at,   :datetime, :null => false
    end
    execute "ALTER TABLE products ADD CONSTRAINT supplier_num_products UNIQUE(supplier_id, supplier_num)"
    
    Product.connection.execute("SELECT setval('products_id_seq',1000)")
    
    create_table :categories_products, :id => false do |t|
      t.column :product_id,  :integer, :null => false
      t.column :category_id, :integer, :null => false
    end
    execute "ALTER TABLE categories_products ADD CONSTRAINT unique_categories_products UNIQUE(product_id, category_id)"
    
    create_table :variants do |t|
      t.column :product_id,   :integer, :null => false
      t.column :supplier_num, :string, :limit => 32, :null => false
      
      t.column :created_at,   :datetime, :null => false
      t.column :updated_at,   :datetime, :null => false
    end
    execute "ALTER TABLE variants ADD CONSTRAINT supplier_num_variants UNIQUE(product_id, supplier_num)"
    
    # Tags
    create_table :tags do |t|
      t.column :name, :string, :null => false, :limit => 16
      t.column :product_id, :integer, :null => false
    end    
    
    # Prices
    create_table :price_groups do |t|
      t.column :currency, :string, :limit => 4
      # null source represents cost
      t.column :source_id,  :integer, :references => :price_sources
      t.column :uri,      :string
    end
    
    create_table :price_entries do |t|
      t.column :price_group_id, :integer, :null => false
      t.column :minimum,        :integer, :null => false
      t.column :fixed,          :integer
      t.column :marginal,       :integer
    end
    execute "ALTER TABLE price_entries ADD CONSTRAINT minimum_price_entries UNIQUE(price_group_id, minimum)"
    
    
    # Variant Prices
    create_table :price_groups_variants, :id => false do |t|
      t.column :price_group_id, :integer, :null => false
      t.column :variant_id,     :integer, :null => false
    end
    execute "ALTER TABLE price_groups_variants ADD CONSTRAINT unique_price_groups_variants UNIQUE(variant_id, price_group_id)"
    
    # Variant Properties
    create_table :properties do |t|
      t.column :name,       :string,  :null => false, :limit => 16
      t.column :value,      :text,    :null => false
    end
    execute "ALTER TABLE properties ADD CONSTRAINT unique_properties UNIQUE(name, value)"
    
    create_table :properties_variants, :id => false do |t|
      t.column :property_id, :integer, :null => false
      t.column :variant_id,  :integer, :null => false
    end
    execute "ALTER TABLE properties_variants ADD CONSTRAINT unique_properties_variants UNIQUE(variant_id, property_id)"
        
    
    # Decorations
    create_table :decoration_techniques do |t|
      t.column :name, :string, :null => false, :limit => 32
      t.column :parent_id, :integer, :references => :decoration_techniques
      t.column :unit_name, :string, :limit => 16
      t.column :unit_default, :integer, :default => 1
    end
    execute "ALTER TABLE decoration_techniques ADD CONSTRAINT unique_decoration_techniques UNIQUE(name)"

    DecorationTechnique.create({:name => "None"})    
    DecorationTechnique.create({:name => "Screen Print", :unit_name => 'colors'})
    DecorationTechnique.create({:name => "Embroidery", :unit_name => 'stiches', :unit_default => nil})
    DecorationTechnique.create({:name => "Deboss", :unit_name => 'area'})
    DecorationTechnique.create({:name => "Personalization", :unit_name => 'names'})
    DecorationTechnique.create({:name => "Photo Transfer"})
    DecorationTechnique.create({:name => "Patch"})
    DecorationTechnique.create({:name => "LogoMagic"})
    DecorationTechnique.create({:name => "Pad Print"})
    DecorationTechnique.create({:name => "Laser Engrave"})
    
    create_table :decoration_price_groups do |t|
      t.column :technique_id,   :integer, :references => :decoration_techniques, :null => false
      t.column :supplier_id,    :integer, :null => false
    end
    execute "ALTER TABLE decoration_price_groups ADD CONSTRAINT unique_decoration_price_groups UNIQUE(supplier_id, technique_id)"
    
    create_table :decoration_price_entries do |t|
      t.column :group_id,         :integer, :references => :decoration_price_groups
      t.column :minimum,          :integer

      t.column :fixed_divisor, :integer, :null => false, :default => 1
      t.column :fixed_offset,  :integer, :null => false, :default => 0           
      t.column :marginal_divisor, :integer, :null => false, :default => 1
      t.column :marginal_offset,  :integer, :null => false, :default => 0     
                  
      t.column :fixed_id,         :integer, :references => :price_groups
      t.column :fixed_price_const,       :float, :null => false, :default => 0.0
      t.column :fixed_price_exp,         :float, :null => false, :default => 0.0
      t.column :fixed_price_marginal,    :integer, :default => 0
      t.column :fixed_price_fixed,       :integer, :default => 0
      
      t.column :marginal_id,      :integer, :references => :price_groups
      t.column :marginal_price_const,    :float, :null => false, :default => 0.0
      t.column :marginal_price_exp,      :float, :null => false, :default => 0.0
      t.column :marginal_price_marginal, :integer, :default => 0
      t.column :marginal_price_fixed,    :integer, :default => 0
    end
    execute "ALTER TABLE decoration_price_entries ADD CONSTRAINT minimum_decoration_price_entries UNIQUE(group_id, minimum)"
    
    create_table :decorations do |t|
      t.column :product_id,   :integer, :null => false
      t.column :technique_id, :integer, :null => false, :references => :decoration_techniques
      t.column :location,     :text
      t.column :limit,        :integer
      t.column :width,        :float
      t.column :height,       :float
      t.column :diameter,     :float
      t.column :triangle,     :float
    end
#    execute "ALTER TABLE decorations ADD CONSTRAINT technique_id_decorations UNIQUE(product_id, technique_id, location)"
  end

  def self.down

  end
end