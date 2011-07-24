ActionController::Routing::Routes.draw do |map|
  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => "welcome#index"

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'

  map.root :controller => 'categories', :action => 'home'
  map.connect 'sitemaps', :controller => 'general', :action => 'sitemaps'

  map.connect 'categories/sitemap', :controller => 'categories', :action => 'sitemap'
  map.connect 'categories/map', :controller => 'categories', :action => 'map'
  map.connect 'categories/*path', :controller => 'categories', :action => 'main'
  map.connect 'categories', :controller => 'categories', :action => 'main'
  
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
