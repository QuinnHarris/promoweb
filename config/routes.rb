Promoweb::Application.routes.draw do
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

  resources :products, :controller => 'admin::Products', :except => [:show] do
    member do
#      get 'show' => 'products#show'
      get 'sitemap' => 'products#sitemap'
    end
  end
  match 'products/:id(.:format)' => 'products#show'
  match 'products/main/:iid' => redirect('/products/%{iid}')

  namespace 'admin' do
    resource :orders do
      get 'items_edit'
      get 'contact_find'
      get 'new_order'
    end

    resources :employees
    resources :suppliers
    resources :login

    resources :phone, :only => [:edit]

    match 'access/paths' => 'access#paths'
    match 'access/calls' => 'access#calls'
  end

  root :to => 'categories#home'

  match 'sitemaps' => 'general#sitemaps'
  match 'categories/sitemap' => 'categories#sitemap'

  match 'categoires/map' => 'categories#map'

  match 'categories/*path' => 'categories#main'
  match 'categories' => 'categories#main'
  
  match 'admin' => 'admin::Login#auth'

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  match ':controller(/:action(/:id(.:format)))'

  # Unidata Provisioning
  match '/e1_:addr.ini' => 'phone#unidata', :constraints => { :addr => /[0-9a-f]{12}/ }
end
