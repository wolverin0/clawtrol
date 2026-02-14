Rails.application.routes.draw do
  mount ActionCable.server => "/cable"

  namespace :api do
    namespace :v1 do
      resource :settings, only: [ :show, :update ]

      resources :agent_personas, only: [ :index, :show, :create, :update, :destroy ] do
        collection do
          post :import
        end
      end

      resources :notifications, only: [:index] do
        collection do
          post :mark_all_read
          post :clear_all
        end
        member do
          post :mark_read
        end
      end

      get "models/status", to: "model_limits#status"
      post "models/best", to: "model_limits#best"
      post "models/:model_name/limit", to: "model_limits#record_limit"
      delete "models/:model_name/limit", to: "model_limits#clear_limit"

      namespace :analytics do
        get :tokens
      end

      namespace :gateway do
        get :health
        get :channels
        get :cost
        get :models
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

      resources :workflows, only: [] do
        member do
          post :run
        end
      end

      resources :task_templates, only: [ :index, :show, :create, :update, :destroy ] do
        collection do
          post :apply
        end
      end

      get "nightshift/tasks", to: "nightshift#tasks"
      post "nightshift/launch", to: "nightshift#launch"
      post "nightshift/arm", to: "nightshift#arm"
      get "nightshift/selections", to: "nightshift#selections"
      patch "nightshift/selections/:id", to: "nightshift#update_selection"

      get "nightshift/missions", to: "nightshift#missions"
      post "nightshift/missions", to: "nightshift#create_mission"
      patch "nightshift/missions/:id", to: "nightshift#update_mission"
      delete "nightshift/missions/:id", to: "nightshift#destroy_mission"
      get "nightshift/tonight", to: "nightshift#tonight"
      post "nightshift/tonight/approve", to: "nightshift#approve_tonight"
      post "nightshift/sync_crons", to: "nightshift#sync_crons"
      post "nightshift/sync_tonight", to: "nightshift#sync_tonight"
      post "nightshift/report_execution", to: "nightshift#report_execution"

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

      post "hooks/agent_complete", to: "hooks#agent_complete"
      post "hooks/task_outcome", to: "hooks#task_outcome"

      # Pipeline API
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

  resources :saved_links, only: [:index, :create, :destroy] do
    post :process_all, on: :collection
  end

  get "dashboard", to: "dashboard#show"
  get "terminal", to: "terminal#show"

  resources :notifications, only: [:index] do
    member do
      patch :mark_read
    end
    collection do
      post :mark_all_read
    end
  end

  get "command", to: "command#index"

  resources :cronjobs, only: [:index, :create, :destroy] do
    member do
      post :toggle
      post :run
    end
  end

  resources :tokens, only: [:index]

  resources :workflows, only: [:index, :new, :create, :edit, :update] do
    collection do
      get :editor
    end
    member do
      get :editor
    end
  end

  get "search", to: "search#index"
  get "analytics", to: "analytics#show"
  get "keys", to: "keys#index"
  patch "keys", to: "keys#update"

  get "nightshift", to: "nightshift#index"
  post "nightshift/launch", to: "nightshift#launch"
  post "nightshift/missions", to: "nightshift#create", as: :nightshift_missions
  patch "nightshift/missions/:id", to: "nightshift#update", as: :nightshift_mission
  delete "nightshift/missions/:id", to: "nightshift#destroy"

  get "nightbeat", to: "nightbeat#index"

  get "factory", to: "factory#index"
  post "factory/loops", to: "factory#create", as: :factory_loops
  patch "factory/loops/:id", to: "factory#update", as: :factory_loop
  delete "factory/loops/:id", to: "factory#destroy", as: :factory_loop_delete
  post "factory/:id/play", to: "factory#play", as: :factory_play
  post "factory/:id/pause", to: "factory#pause", as: :factory_pause
  post "factory/:id/stop", to: "factory#stop", as: :factory_stop
  post "factory/bulk_play", to: "factory#bulk_play", as: :factory_bulk_play
  post "factory/bulk_pause", to: "factory#bulk_pause", as: :factory_bulk_pause

  resources :agent_personas do
    collection do
      post :import
      get :roster
    end
  end

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
        get :chat_history
      end
    end
  end

  get "board", to: redirect { |params, request| "/boards" }
  get "pages/home"

  get "up" => "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :outputs, only: [:index, :show], controller: "previews" do
    member do
      get :raw
    end
  end

  resources :showcases, only: [:index, :show] do
    member do
      get :raw
      patch :toggle_winner
    end
  end

  get "marketing", to: "marketing#index", as: :marketing
  get "marketing/playground", to: "marketing#playground", as: :marketing_playground
  get "marketing/generated_content", to: "marketing#generated_content", as: :marketing_generated_content
  post "marketing/generate_image", to: "marketing#generate_image", as: :marketing_generate_image
  post "marketing/publish", to: "marketing#publish_to_n8n", as: :marketing_publish
  get "marketing/*path", to: "marketing#show", as: :marketing_show, format: false

  get "view", to: "file_viewer#show"
  get "files", to: "file_viewer#browse", as: :browse_files

  root "pages#home"
end
