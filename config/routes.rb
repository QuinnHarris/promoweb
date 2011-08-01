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

  match 'products/sitemap' => 'products#sitemap'
  resources :products, :controller => 'admin::Products', :except => [:show]
  match 'products/:id(.:format)' => 'products#show'
  match 'products/main/:iid' => redirect('/products/%{iid}')

  match '/admin/orders/task_execute' => 'admin::Orders#task_execute'

  namespace 'admin' do
    resource :orders do
      %w(person_name company_name email_addresses phone_numbers).each do |name|
        post "auto_complete_for_customer_#{name}"
      end
      get 'items_edit'
      get 'contact_find'
      get 'new_order'
      post 'payment_apply'
      get 'contact_search'
      post 'contact_find'
      get 'contact_merge'
      get 'task_revoke'
      get 'order_duplicate'
      get 'artwork_group_new'
      post 'artwork_drop_set'
      get 'artwork_generate_pdf'
      get 'order_own'
      post 'variant_change'
      post 'set'
      post 'auto_complete_generic'
    end

    resources :employees
    resources :suppliers
    %w(logout password).each do |name|
      match "users/#{name}" => "users##{name}"
    end
    resources :users do
      resources :phones, :only => [:index, :create, :destroy]
    end

    resources :phone, :only => [:edit]

    %w(paths calls inbound).each do |name|
      match "access/#{name}" => "access##{name}"
    end

    %w(quickbooks_blocked quickbooks_set other).each do |name|
      match "system/#{name}" => "system##{name}"
    end
  end

  root :to => 'categories#home'

  match 'sitemaps' => 'general#sitemaps'
  match 'categories/sitemap' => 'categories#sitemap'

  match 'categoires/map' => 'categories#map'
  match 'categories/*path' => 'categories#main'
  match 'categories' => 'categories#main'

  match 'search' => 'search#index'

  match 'static/:action', :controller => 'static'

  match 'order/:action(/:id(.:format))', :controller => 'order'
#  resource :orders, :only => [:index, :show] do
#    get 'status'
#    get 'info'
#    get 'contact'

#    resource :items, :only => [:create, :destroy]
#    resource :artworks, :only => [:create, :destroy]
#  end
  
  match 'admin' => 'admin::Users#auth'

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  match ':controller(/:action(/:id(.:format)))'

  # Unidata Provisioning
  match '/e1_:addr.ini' => 'phone#unidata', :constraints => { :addr => /[0-9a-f]{12}/ }
end
