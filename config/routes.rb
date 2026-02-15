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
        get :plugins
        get :nodes_status
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

      # Swarm Ideas API
      resources :swarm_ideas, only: [:index, :create, :update, :destroy] do
        member do
          post :launch
        end
      end

      # Pipeline API (ClawRouter 3-layer pipeline)
      get "pipeline/status", to: "pipeline#status"
      post "pipeline/enable_board/:board_id", to: "pipeline#enable_board"
      post "pipeline/disable_board/:board_id", to: "pipeline#disable_board"
      get "pipeline/task/:id/log", to: "pipeline#task_log"
      post "pipeline/reprocess/:id", to: "pipeline#reprocess"

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

      post "hooks/agent_complete", to: "hooks#agent_complete"
      post "hooks/task_outcome", to: "hooks#task_outcome"

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
  resources :saved_links, only: [:index, :create, :update, :destroy] do
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
  get "analytics/budget", to: "analytics#budget", as: :analytics_budget
  post "analytics/budget", to: "analytics#update_budget", as: :update_analytics_budget
  post "analytics/capture", to: "analytics#capture_snapshot", as: :capture_analytics_snapshot

  # Session maintenance configuration
  get   "session-maintenance", to: "session_maintenance#show",   as: :session_maintenance
  patch "session-maintenance", to: "session_maintenance#update",  as: :session_maintenance_update

  # Typing indicator configuration
  get   "typing-config", to: "typing_config#show",   as: :typing_config
  patch "typing-config", to: "typing_config#update",  as: :typing_config_update

  # Identity & branding configuration
  get   "identity-config", to: "identity_config#show",   as: :identity_config
  patch "identity-config", to: "identity_config#update",  as: :identity_config_update

  # Send policy & access groups
  get   "send-policy", to: "send_policy#show",   as: :send_policy
  patch "send-policy", to: "send_policy#update",  as: :send_policy_update

  # Hooks & Gmail PubSub dashboard
  get "hooks-dashboard", to: "hooks_dashboard#show", as: :hooks_dashboard

  # CLI backends configuration
  get   "cli-backends", to: "cli_backends#index",   as: :cli_backends
  patch "cli-backends", to: "cli_backends#update",   as: :cli_backends_update

  # Custom model provider registry
  get   "model-providers",      to: "model_providers#index",         as: :model_providers
  patch "model-providers",      to: "model_providers#update",         as: :model_providers_update
  post  "model-providers/test", to: "model_providers#test_provider",  as: :model_providers_test

  # Sandbox configuration
  get   "sandbox-config", to: "sandbox_config#show",   as: :sandbox_config
  patch "sandbox-config", to: "sandbox_config#update",  as: :sandbox_config_update

  # Compaction & context pruning configuration
  get   "compaction-config", to: "compaction_config#show",   as: :compaction_config
  patch "compaction-config", to: "compaction_config#update",  as: :compaction_config_update

  # Heartbeat configuration
  get   "heartbeat-config", to: "heartbeat_config#show",   as: :heartbeat_config
  patch "heartbeat-config", to: "heartbeat_config#update",  as: :heartbeat_config_update

  # Session reset policy configuration
  get   "session-reset", to: "session_reset_config#show",   as: :session_reset_config
  patch "session-reset", to: "session_reset_config#update",  as: :session_reset_config_update

  # Message Queue configuration
  get   "message-queue", to: "message_queue_config#show",   as: :message_queue_config
  patch "message-queue", to: "message_queue_config#update",  as: :message_queue_config_update

  # DM Policy & Pairing Manager
  get   "dm-policy",                to: "dm_policy#show",            as: :dm_policy
  patch "dm-policy",                to: "dm_policy#update",           as: :dm_policy_update
  post  "dm-policy/approve-pairing", to: "dm_policy#approve_pairing", as: :dm_policy_approve_pairing
  post  "dm-policy/reject-pairing",  to: "dm_policy#reject_pairing",  as: :dm_policy_reject_pairing

  # Multi-account channel manager
  get   "channel-accounts", to: "channel_accounts#show",   as: :channel_accounts
  patch "channel-accounts", to: "channel_accounts#update",  as: :channel_accounts_update

  # Media (audio/video/image) configuration
  get   "media-config", to: "media_config#show",   as: :media_config
  patch "media-config", to: "media_config#update",  as: :media_config_update

  # Webchat embed (OpenClaw webchat iframe with task context)
  get "webchat", to: "webchat#show", as: :webchat

  # Canvas / A2UI push dashboard
  get  "canvas",          to: "canvas#show",      as: :canvas
  post "canvas/push",     to: "canvas#push",      as: :canvas_push
  post "canvas/snapshot", to: "canvas#snapshot",   as: :canvas_snapshot
  post "canvas/hide",     to: "canvas#hide",       as: :canvas_hide
  get  "canvas/templates", to: "canvas#templates", as: :canvas_templates

  # Paired nodes
  get "nodes", to: "nodes#index"

  # Session explorer
  get "sessions", to: "sessions_explorer#index", as: :sessions_explorer

  # Skill browser
  # Skills — replaced by SkillManagerController (enhanced version with gateway integration)
  # get "skills", to: "skills#index"  # OLD read-only skill browser

  # Public status page (no auth required)
  get "status", to: "status#show"

  # Telegram Mini App (no Rails auth — validated via Telegram initData)
  # Telegram Advanced Config
  get "telegram_config", to: "telegram_config#show", as: :telegram_config
  post "telegram_config/update", to: "telegram_config#update", as: :telegram_config_update

  # Discord Advanced Config
  get "discord_config", to: "discord_config#show", as: :discord_config
  post "discord_config/update", to: "discord_config#update", as: :discord_config_update

  # Logging & Debug Config
  get "logging_config", to: "logging_config#show", as: :logging_config
  post "logging_config/update", to: "logging_config#update", as: :logging_config_update
  get "logging_config/tail", to: "logging_config#tail", as: :logging_config_tail

  # Config Hub — central navigation for all config pages
  get "config", to: "config_hub#show", as: :config_hub

  # Hot Reload Monitor
  get "hot_reload", to: "hot_reload#show", as: :hot_reload
  post "hot_reload/update", to: "hot_reload#update", as: :hot_reload_update

  # Channel Config (Mattermost/Slack/Signal)
  get "channel_config/:channel", to: "channel_config#show", as: :channel_config
  post "channel_config/:channel/update", to: "channel_config#update", as: :channel_config_update

  # Environment Variable Manager
  get "env_manager", to: "env_manager#show", as: :env_manager
  get "env_manager/file", to: "env_manager#file_contents", as: :env_manager_file
  post "env_manager/test", to: "env_manager#test_substitution", as: :env_manager_test

  get "telegram_app", to: "telegram_mini_app#show"
  post "telegram_app/tasks", to: "telegram_mini_app#tasks"
  post "telegram_app/boards", to: "telegram_mini_app#boards", as: :telegram_app_boards
  post "telegram_app/tasks/create", to: "telegram_mini_app#create_task"
  post "telegram_app/tasks/:id/approve", to: "telegram_mini_app#approve", as: :telegram_app_approve
  post "telegram_app/tasks/:id/reject", to: "telegram_mini_app#reject", as: :telegram_app_reject

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

  # Swarm Launcher
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

  # Cherry-pick pipeline
  get "factory/cherry_pick", to: "factory#cherry_pick_index", as: :factory_cherry_pick
  post "factory/cherry_pick/preview", to: "factory#cherry_pick_preview", as: :factory_cherry_pick_preview
  post "factory/cherry_pick/execute", to: "factory#cherry_pick_execute", as: :factory_cherry_pick_execute
  post "factory/cherry_pick/verify", to: "factory#cherry_pick_verify", as: :factory_cherry_pick_verify

  # Gateway Config Editor
  get "gateway/config", to: "gateway_config#show", as: :gateway_config
  post "gateway/config/apply", to: "gateway_config#apply", as: :gateway_config_apply
  post "gateway/config/patch", to: "gateway_config#patch_config", as: :gateway_config_patch
  post "gateway/config/restart", to: "gateway_config#restart", as: :gateway_config_restart

  # Block Streaming Config
  get "streaming", to: "block_streaming#show", as: :block_streaming
  patch "streaming/update", to: "block_streaming#update", as: :block_streaming_update

  # DM Scope Security Audit
  get "security/dm_scope", to: "dm_scope_audit#show", as: :dm_scope_audit

  # Live Events (Mission Control)
  get "live", to: "live_events#show", as: :live_events
  get "live/poll", to: "live_events#poll", as: :live_events_poll

  # Identity Links
  get "identity_links", to: "identity_links#index", as: :identity_links
  post "identity_links/save", to: "identity_links#save", as: :identity_links_save

  # Compaction Dashboard
  get "compaction", to: "compaction_dashboard#show", as: :compaction_dashboard

  # Memory Dashboard
  get "memory", to: "memory_dashboard#show", as: :memory_dashboard
  post "memory/search", to: "memory_dashboard#search", as: :memory_search

  # Exec Approvals Manager
  get "exec_approvals", to: "exec_approvals#index", as: :exec_approvals
  post "exec_approvals/add", to: "exec_approvals#add", as: :exec_approvals_add
  delete "exec_approvals/remove", to: "exec_approvals#remove", as: :exec_approvals_remove
  post "exec_approvals/bulk_import", to: "exec_approvals#bulk_import", as: :exec_approvals_bulk_import

  # Skill Manager
  get "skills", to: "skill_manager#index", as: :skill_manager
  post "skills/install", to: "skill_manager#install", as: :skill_install
  post "skills/:name/toggle", to: "skill_manager#toggle", as: :skill_toggle
  post "skills/:name/configure", to: "skill_manager#configure", as: :skill_configure
  delete "skills/:name", to: "skill_manager#uninstall", as: :skill_uninstall

  # Webhook Mapping Builder
  get "webhooks/mappings", to: "webhook_mappings#index", as: :webhook_mappings
  post "webhooks/mappings/save", to: "webhook_mappings#save", as: :webhook_mappings_save
  post "webhooks/mappings/preview", to: "webhook_mappings#preview", as: :webhook_mappings_preview

  # Multi-Agent Config
  get "agents/config", to: "agent_config#show", as: :agent_config
  patch "agents/config/update_agent", to: "agent_config#update_agent", as: :agent_config_update_agent
  patch "agents/config/update_bindings", to: "agent_config#update_bindings", as: :agent_config_update_bindings

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
      post :generate_persona
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
  # Mobile quick-add task
  get "quick_add", to: "quick_add#new", as: :quick_add
  post "quick_add", to: "quick_add#create"

  get "pages/home"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
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

  # Defines the root path route ("/")
  root "pages#home"
end
