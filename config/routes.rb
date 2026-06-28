Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get    "sign_in",        to: "sessions#new"
  post   "sign_in",        to: "sessions#create"
  get    "sign_in/:token", to: "sessions#show", as: :sign_in_with_token
  delete "sign_out",       to: "sessions#destroy", as: :sign_out

  resources :invitations, only: %i[ index new create destroy ]
  get  "invitations/:token", to: "invitations#show",   as: :accept_invitation
  post "invitations/:token", to: "invitations#accept", as: :claim_invitation

  resources :projects, only: %i[ index new create show edit update destroy ] do
    member do
      get :activity
      get :settings
    end
    resources :locales, only: %i[ create update destroy ]
    resources :namespaces, only: %i[ create update destroy show ], constraints: { id: %r{[^/]+} } do
      resource :publication, only: :create, module: :namespaces
      resource :import,      only: :create, module: :namespaces
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
  get "cdn/:project_slug/:locale/:namespace" => "delivery#show",
      as: :delivery,
      format: false,
      constraints: {
        locale: /[a-zA-Z]{2,3}(-[a-zA-Z0-9]{2,8})*/,
        namespace: /[a-z0-9][a-z0-9_\-.]*/
      }

  root "projects#index"
end
