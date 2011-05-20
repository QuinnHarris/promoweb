ActionController::Routing::Routes.draw do |map|
  # The priority is based upon order of creation: first created -> highest priority.

  # Sample of regular route:
  #   map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   map.resources :products

  # Sample resource route with options:
  #   map.resources :products, :member => { :short => :get, :toggle => :post }, :collection => { :sold => :get }

  # Sample resource route with sub-resources:
  #   map.resources :products, :has_many => [ :comments, :sales ], :has_one => :seller
  
  # Sample resource route with more complex sub-resources
  #   map.resources :products do |products|
  #     products.resources :comments
  #     products.resources :sales, :collection => { :recent => :get }
  #   end

  # Sample resource route within a namespace:
  #   map.namespace :admin do |admin|
  #     # Directs /admin/products/* to Admin::ProductsController (app/controllers/admin/products_controller.rb)
  #     admin.resources :products
  #   end

  # You can have the root of your site routed with map.root -- just remember to delete public/index.html.
  # map.root :controller => "welcome"

  # See how all your routes lay out with "rake routes"

  map.root :controller => 'categories', :action => 'home'
  map.connect 'sitemaps', :controller => 'general', :action => 'sitemaps'

  map.connect 'categories/sitemap', :controller => 'categories', :action => 'sitemap'
  map.connect 'categories/map', :controller => 'categories', :action => 'map'
  map.connect 'categories/*path', :controller => 'categories', :action => 'main'
  
  map.connect 'products/sitemap', :controller => 'products', :action => 'sitemap'
#  map.connect 'products/:id', :controller => 'products', :action => 'main'

  map.connect 'admin', :controller => '/admin/login', :action => 'auth'

#  map.resources :order
  
  # Install the default route as the lowest priority.
  map.connect ':controller/:action/:id.:format'
  map.connect ':controller/:action/:id'

  # Unidata Provisioning
  map.connect ':name', :controller => '/phone', :action => 'unidata', :name => /e1_[0-9a-f]{12}.ini/, :conditions => { :method => :get }
end
