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
    resources :locales, only: %i[ create update destroy ]
    resources :namespaces, only: %i[ create update destroy show ], constraints: { id: %r{[^/]+} } do
      member do
        post :publish_all
        post :import
      end
      resources :translation_keys, only: %i[ create update destroy ]
    end
    resources :translations, only: %i[ create update ] do
      resource :publication, only: %i[ create destroy ], module: :translations
    end
  end

  root "projects#index"
end
