Rails.application.routes.draw do
  # ActionCable endpoint (required for Turbo Streams + custom channels)
  mount ActionCable.server => "/cable"

  # API routes
  namespace :api do
    namespace :v1 do
      resource :settings, only: [ :show, :update ]

      # Agent Personas
      resources :agent_personas, only: [ :index, :show, :create, :update, :destroy ] do
        collection do
          post :import
        end
      end

      # Notifications
      resources :notifications, only: [:index] do
        collection do
          post :mark_all_read
          post :clear_all
        end
        member do
          post :mark_read
        end
      end

      # Model rate limit tracking
      get "models/status", to: "model_limits#status"
      post "models/best", to: "model_limits#best"
      post "models/:model_name/limit", to: "model_limits#record_limit"
      delete "models/:model_name/limit", to: "model_limits#clear_limit"

      # Analytics
      namespace :analytics do
        get :tokens
      end

      resources :saved_links, only: [:index, :create, :update] do
        collection do
          get :pending
        end
      end

      resources :boards, only: [ :index, :show, :create, :update, :destroy ] do
        member do
          get :status
        end
      end

      # Task templates for slash commands
      resources :task_templates, only: [ :index, :show, :create, :update, :destroy ] do
        collection do
          post :apply
        end
      end

      # Nightshift API
      get "nightshift/tasks", to: "nightshift#tasks"
      post "nightshift/launch", to: "nightshift#launch"
      post "nightshift/arm", to: "nightshift#arm"
      get "nightshift/selections", to: "nightshift#selections"
      patch "nightshift/selections/:id", to: "nightshift#update_selection"

      post "hooks/agent_complete", to: "hooks#agent_complete"
      post "hooks/task_outcome", to: "hooks#task_outcome"

      resources :tasks, only: [ :index, :show, :create, :update, :destroy ] do
        collection do
          get :next
          get :pending_attention
          get :recurring
          get :errored_count
          post :spawn_ready
        end
        member do
          patch :complete
          post :agent_complete
          patch :claim
          patch :unclaim
          post :requeue
          patch :assign
          patch :unassign
          patch :move
          get :agent_log
          get :session_health
          post :generate_followup
          post :enhance_followup
          post :create_followup
          post :handoff
          post :link_session
          post :report_rate_limit
          post :revalidate
          post :start_validation
          post :run_debate
          post :complete_review
          post :recover_output
          get :file
          post :add_dependency
          delete :remove_dependency
          get :dependencies
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
  resource :settings, only: [ :show, :update ], controller: "profiles" do
    post :regenerate_api_token
    post :test_connection
  end

  # Link Inbox
  resources :saved_links, only: [:index, :create, :destroy] do
    post :process_all, on: :collection
  end

  # Dashboard overview page
  get "dashboard", to: "dashboard#show"

  # Agent Swarm View
  get "command", to: "command#index"

  # Global search
  get "search", to: "search#index"

  # Analytics page
  get "analytics", to: "analytics#show"

  # API Keys management
  get "keys", to: "keys#index"
  patch "keys", to: "keys#update"

  # Nightshift mission control
  get "nightshift", to: "nightshift#index"
  post "nightshift/launch", to: "nightshift#launch"

  # Nightbeat morning brief
  get "nightbeat", to: "nightbeat#index"

  # Agent Personas
  resources :agent_personas do
    collection do
      post :import
      get :roster
    end
  end

  # Boards (multi-board kanban views)
  resources :boards, only: [ :index, :show, :create, :update, :destroy ] do
    member do
      patch :update_task_status
      get :archived
      get :column
    end
    resources :tasks, only: [ :show, :new, :create, :edit, :update, :destroy ], controller: "boards/tasks" do
      collection do
        post :bulk_update
      end
      member do
        patch :assign
        patch :unassign
        patch :move
        patch :move_to_board
        get :followup_modal
        get :handoff_modal
        get :validation_output_modal
        get :validate_modal
        get :debate_modal
        get :review_output_modal
        post :generate_followup
        post :enhance_followup
        post :create_followup
        post :handoff
        post :revalidate
        post :run_validation
        post :run_debate
        post :generate_validation_suggestion
        get :view_file
        get :diff_file
      end
    end
  end

  # Redirect root board path to first board
  get "board", to: redirect { |params, request|
    # This will be handled by the controller for proper user scoping
    "/boards"
  }
  get "pages/home"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Output gallery for agent-generated content
  resources :outputs, only: [:index, :show], controller: 'previews' do
    member do
      get :raw
    end
  end

  # Showcase gallery for redesign mockups
  resources :showcases, only: [:index, :show] do
    member do
      get :raw
      patch :toggle_winner
    end
  end

  # Marketing docs file browser
  get "marketing", to: "marketing#index", as: :marketing
  get "marketing/playground", to: "marketing#playground", as: :marketing_playground
  get "marketing/generated_content", to: "marketing#generated_content", as: :marketing_generated_content
  post "marketing/generate_image", to: "marketing#generate_image", as: :marketing_generate_image
  post "marketing/publish", to: "marketing#publish_to_n8n", as: :marketing_publish
  get "marketing/*path", to: "marketing#show", as: :marketing_show, format: false

  # File viewer (workspace files, no auth)
  get "view", to: "file_viewer#show"

  # Defines the root path route ("/")
  root "pages#home"
end
