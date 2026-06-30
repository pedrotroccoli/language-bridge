Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get    "sign_in",        to: "sessions#new"
  post   "sign_in",        to: "sessions#create"
  get    "sign_in/:token", to: "sessions#show", as: :sign_in_with_token
  delete "sign_out",       to: "sessions#destroy", as: :sign_out

  resources :invitations, only: %i[ index new create destroy ] do
    member { post :resend }
  end
  get  "invitations/:token", to: "invitations#show",   as: :accept_invitation
  post "invitations/:token", to: "invitations#accept", as: :claim_invitation

  # Global, admin-only workspace settings (rate-limit defaults).
  resource :workspace, only: %i[ show update ], controller: "workspace"

  resources :storage_connections, only: %i[ create update destroy ] do
    resource :default, only: :create, controller: "storage_connections/defaults"
    collection { post :test } # verify (unsaved) connection params
  end

  # Workspace members (users) and the signed-in user's own account.
  resources :members, only: %i[ index update destroy ]
  resource :account, only: %i[ show update ], controller: "account"
  namespace :account do
    resource :sessions, only: :destroy # revoke all sessions but the current one
  end

  resources :projects, only: %i[ index new create show edit update destroy ] do
    resource :activity, only: :show, controller: "projects/activity"
    resource :settings, only: :show, controller: "projects/settings"
    resource :upload_settings, only: :update, controller: "projects/upload_settings"
    resource :delivery_sync, only: :create, controller: "projects/delivery_sync"
    resources :api_tokens, only: %i[ create destroy ], controller: "projects/api_tokens"
    resources :missing, only: %i[ index destroy ], controller: "projects/missing" do
      resource :promotion, only: :create, controller: "projects/missing/promotions"
    end
    resources :backups, only: %i[ index create destroy ], controller: "projects/backups" do
      resource :restoration, only: :create, controller: "projects/backups/restorations"
    end
    resource :backup_schedule, only: :update, controller: "projects/backup_schedules"
    resources :locales, only: %i[ create update destroy ] do
      member { post :source }
    end
    resources :namespaces, only: %i[ create update destroy show ], constraints: { id: %r{[^/]+} } do
      resource :publication, only: :create, module: :namespaces
      resource :import,      only: :create, module: :namespaces
      resource :export,      only: :show,    module: :namespaces
      resource :drafts,      only: :destroy, module: :namespaces
      resources :translation_keys, only: %i[ create update destroy ]
    end
    resources :translations, only: %i[ create update ] do
      resource :publication, only: %i[ create destroy ], module: :translations
    end
  end

  # Public i18n delivery. Mounted under /cdn to avoid any collision with
  # top-level app routes. namespace may contain dots, so the optional ".json"
  # suffix (i18next loadPath convention) is stripped in the controller rather
  # than parsed as a format.
  namespace :api do
    namespace :v1 do
      post "projects/:project_slug/missing", to: "missing_translations#create"
    end
  end

  get "cdn/:project_slug/:locale/:namespace" => "delivery#show",
      as: :delivery,
      format: false,
      constraints: {
        locale: /[a-zA-Z]{2,3}(-[a-zA-Z0-9]{2,8})*/,
        namespace: /[a-z0-9][a-z0-9_\-.]*/
      }

  root "projects#index"
end
