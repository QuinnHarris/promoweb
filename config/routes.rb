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
  match 'products/rss' => 'products#rss'
  resources :products, :controller => 'admin::Products', :except => [:show]
  match 'products/:id(.:format)' => 'products#show'
  match 'products/main/:iid' => redirect('/products/%{iid}')

  match '/admin/orders/shipping_get' => 'admin::Orders#shipping_get'

  namespace 'admin' do
    resource :orders do
      %w(person_name company_name email_addresses phone_numbers).each do |name|
        post "auto_complete_for_customer_#{name}"
      end
      get 'contact_find'
      get 'new_order'
      get 'contact_search'
      post 'contact_find'
      get 'contact_merge'
      post 'variant_change'
      post 'set'
      post 'auto_complete_generic'
      
      get 'order_item_remove'
      get 'order_item_entry_insert'
      get 'order_item_decoration_insert'
      get 'order_entry_insert'

      get 'shipping_get'
      post 'shipping_set'

      get 'po'
      get 'purchase_mark'
    end

    resources :employees
    resources :suppliers, :except => [:show]
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

  match 'order/:name' => 'orders#legacy_redirect'
  resources :orders, :only => [:index, :show] do
    collection do
      post 'add' => 'order_items#add'
    end

    member do
      get 'status'
      get 'items'
      post 'items'
      get 'info'
      post 'info'
      get 'contact'
      post 'contact'
      get 'artwork'
      get 'payment'
      get 'payment_creditcard'
      post 'payment_creditcard'
      post 'payment_sendcheck'
      post 'payment_use'
      post 'payment_remove'

      get 'review'
      get 'acknowledge_order'
      get 'acknowledge_artwork'

      # Temp
      post 'artwork_add'
      post 'artwork_edit'
      get 'artwork_remove'

      namespace :admin do
        get 'items'
        get 'email'
        get 'access'
        delete 'destroy'

        post 'duplicate'
        post 'restore'
        
        post 'payment_apply'
        post 'own'

        put 'purchase_create'

        delete 'task_revoke'
        put 'task_execute'
        post 'task_comment'
      end
    end

    resources :items, :only => [:destroy], :controller => 'order_items'

    resource :artwork, :controller => 'artwork', :only => [] do
      post 'edit'
      scope :module => :admin do
        post 'drop_set'
        post 'group_new'
        post 'group_destroy'
        post 'make_proof'
        get 'inkscape'
      end
    end

    resources :artwork, :only => [:destroy, :create] do
      member do
        scope :module => :admin do
          post 'mark'
        end
      end
    end
  end
  
  match 'admin' => 'admin::Users#auth'

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  #  match ':controller(/:action(/:id(.:format)))'

  # Unidata Provisioning
  match '/e1_:addr.ini' => 'phone#unidata', :constraints => { :addr => /[0-9a-f]{12}/ }
end
