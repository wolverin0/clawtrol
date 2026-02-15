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

      # Gateway proxy endpoints
      namespace :gateway do
        get :health
        get :channels
        get :cost
        get :models
      end

      # Model performance comparison
      get "model_performance", to: "model_performance#show"
      get "model_performance/summary", to: "model_performance#summary"

      resources :saved_links, only: [:index, :create, :update] do
        collection do
          get :pending
        end
      end

      # Feed entries (n8n pushes RSS/feed items here)
      resources :feed_entries, only: [:index, :create, :update] do
        collection do
          get :stats
        end
      end

      resources :boards, only: [ :index, :show, :create, :update, :destroy ] do
        member do
          get :status
        end
      end

      resources :workflows, only: [] do
        member do
          post :run
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

      # Nightshift Missions API (v2)
      get "nightshift/missions", to: "nightshift#missions"
      post "nightshift/missions", to: "nightshift#create_mission"
      patch "nightshift/missions/:id", to: "nightshift#update_mission"
      delete "nightshift/missions/:id", to: "nightshift#destroy_mission"
      get "nightshift/tonight", to: "nightshift#tonight"
      post "nightshift/tonight/approve", to: "nightshift#approve_tonight"
      post "nightshift/sync_crons", to: "nightshift#sync_crons"
      post "nightshift/sync_tonight", to: "nightshift#sync_tonight"
      post "nightshift/report_execution", to: "nightshift#report_execution"

      # Factory API
      get "factory/loops", to: "factory_loops#index"
      post "factory/loops", to: "factory_loops#create"
      get "factory/loops/:id", to: "factory_loops#show"
      patch "factory/loops/:id", to: "factory_loops#update"
      delete "factory/loops/:id", to: "factory_loops#destroy"
      post "factory/loops/:id/play", to: "factory_loops#play"
      post "factory/loops/:id/pause", to: "factory_loops#pause"
      post "factory/loops/:id/stop", to: "factory_loops#stop"
      get "factory/loops/:id/metrics", to: "factory_loops#metrics"
      post "factory/cycles/:id/complete", to: "factory_cycles#complete"

      resources :swarm_ideas, only: [:index, :create, :update, :destroy] do
        member do
          post :launch
        end
      end

      post "hooks/agent_complete", to: "hooks#agent_complete"
      post "hooks/task_outcome", to: "hooks#task_outcome"

      # Pipeline API (ClawRouter 3-layer pipeline)
      get "pipeline/status", to: "pipeline#status"
      post "pipeline/enable_board/:board_id", to: "pipeline#enable_board"
      post "pipeline/disable_board/:board_id", to: "pipeline#disable_board"
      get "pipeline/task/:id/log", to: "pipeline#task_log"
      post "pipeline/reprocess/:id", to: "pipeline#reprocess"

      resources :tasks, only: [ :index, :show, :create, :update, :destroy ] do
        collection do
          get :next
          get :pending_attention
          get :recurring
          get :errored_count
          post :spawn_ready
          get :export
          post :import
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
          post :route_pipeline
          get :pipeline_info
          post :add_dependency
          delete :remove_dependency
          get :dependencies
        end

        resources :agent_messages, only: [:index] do
          collection do
            get :thread
          end
        end
      end
    end
  end

  namespace :admin do
    root to: "dashboard#index"
    resources :users, only: [ :index ]
    resources :invite_codes, only: [:index, :create, :destroy]
  end

  resource :session, only: [:new, :create, :destroy]
  resource :registration, only: [:new, :create]
  get "/auth/:provider/callback", to: "omniauth_callbacks#github", as: :omniauth_callback
  get "/auth/failure", to: "omniauth_callbacks#failure"
  resources :passwords, param: :token
  resource :settings, only: [ :show, :update ], controller: "profiles" do
    post :regenerate_api_token
    post :test_connection
    post :test_notification
  end

  # Link Inbox
  resources :saved_links, only: [:index, :create, :destroy] do
    post :process_all, on: :collection
  end

  # Feed Monitor Dashboard
  resources :feeds, only: [:index, :show, :update, :destroy] do
    collection do
      post :mark_read
    end
    member do
      post :dismiss
    end
  end

  # Dashboard overview page
  get "dashboard", to: "dashboard#show"

  # Web Terminal
  get "terminal", to: "terminal#show"

  # Notifications
  resources :notifications, only: [:index] do
    member do
      patch :mark_read
    end
    collection do
      post :mark_all_read
    end
  end

  # Agent Swarm View
  get "command", to: "command#index"

  # Cron jobs (OpenClaw Gateway)
  resources :cronjobs, only: [:index, :create, :destroy] do
    member do
      post :toggle
      post :run
    end
  end

  # Token usage
  resources :tokens, only: [:index]

  # Workflows
  resources :workflows, only: [:index, :new, :create, :edit, :update] do
    collection do
      get :editor
    end
    member do
      get :editor
    end
  end

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
  post "nightshift/missions", to: "nightshift#create", as: :nightshift_missions
  patch "nightshift/missions/:id", to: "nightshift#update", as: :nightshift_mission
  delete "nightshift/missions/:id", to: "nightshift#destroy"

  # Nightbeat morning brief
  get "nightbeat", to: "nightbeat#index"

  # Swarm
  get "swarm", to: "swarm#index"
  post "swarm/launch/:id", to: "swarm#launch", as: :swarm_launch
  post "swarm", to: "swarm#create", as: :create_swarm_idea
  delete "swarm/:id", to: "swarm#destroy", as: :destroy_swarm_idea
  patch "swarm/:id", to: "swarm#update", as: :update_swarm_idea
  patch "swarm/:id/toggle_favorite", to: "swarm#toggle_favorite", as: :toggle_favorite_swarm_idea

  # Factory dashboard
  get "factory", to: "factory#index"
  get "factory/playground", to: "factory#playground", as: :factory_playground
  post "factory/loops", to: "factory#create", as: :factory_loops
  patch "factory/loops/:id", to: "factory#update", as: :factory_loop
  delete "factory/loops/:id", to: "factory#destroy", as: :factory_loop_delete
  post "factory/:id/play", to: "factory#play", as: :factory_play
  post "factory/:id/pause", to: "factory#pause", as: :factory_pause
  post "factory/:id/stop", to: "factory#stop", as: :factory_stop
  post "factory/bulk_play", to: "factory#bulk_play", as: :factory_bulk_play
  post "factory/bulk_pause", to: "factory#bulk_pause", as: :factory_bulk_pause

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
      get :dependency_graph
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
        get :chat_history
      end
    end
  end

  # Redirect root board path to first board
  get "board", to: redirect { |params, request| "/boards" }

  # Mobile quick-add task
  get "quick_add", to: "quick_add#new", as: :quick_add
  post "quick_add", to: "quick_add#create"

  get "pages/home"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Output gallery for agent-generated content
  resources :outputs, only: [:index, :show], controller: "previews" do
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
  get "files", to: "file_viewer#browse", as: :browse_files

  # Root
  root "pages#home"
end
