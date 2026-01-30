Rails.application.routes.draw do
  # API routes
  namespace :api do
    namespace :v1 do
      resource :inbox, only: [], controller: "inbox" do
        resources :tasks, only: [ :index, :create ], controller: "inbox"
      end
      resources :projects, only: [ :index, :show, :create ] do
        resources :tasks, only: [ :index, :create ]
      end
      resources :tasks, only: [ :show, :update, :destroy ] do
        member do
          patch :complete
        end
      end
    end
  end

  namespace :admin do
    root to: "dashboard#index"
    resources :users, only: [ :index ]
  end

  resource :session, only: [:new, :create, :destroy]
  resource :registration, only: [:new, :create]
  get "/auth/:provider/callback", to: "omniauth_callbacks#github", as: :omniauth_callback
  get "/auth/failure", to: "omniauth_callbacks#failure"
  resources :passwords, param: :token
  resource :profile, only: [ :show, :update ] do
    post :regenerate_api_token
  end
  resource :inbox, only: [ :show ], controller: "inbox" do
    resources :tasks, only: [ :create, :edit, :update, :destroy ], controller: "inbox/tasks" do
      member do
        patch :toggle_completed
        patch :cycle_priority
        patch :send_to
      end
      collection do
        post :reorder
      end
    end
  end

  resource :today, only: [ :show ], controller: "today" do
    resources :tasks, only: [ :create ], controller: "today/tasks"
  end

  resources :projects do
    collection do
      post :reorder
    end
    resource :task_list, only: [ :update ] do
      delete :delete_all_tasks
      delete :delete_completed_tasks
    end
    resources :tasks, only: [ :create, :edit, :update, :destroy ] do
      member do
        patch :toggle_completed
        patch :cycle_priority
        patch :send_to
      end
      collection do
        post :reorder
      end
    end
  end
  get "pages/home"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "pages#home"
end
