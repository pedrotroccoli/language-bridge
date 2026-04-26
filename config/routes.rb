Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get    "sign_in",        to: "sessions#new"
  post   "sign_in",        to: "sessions#create"
  get    "sign_in/:token", to: "sessions#show", as: :sign_in_with_token
  delete "sign_out",       to: "sessions#destroy", as: :sign_out

  resources :invitations, only: %i[ index new create destroy ]
  get  "invitations/:token", to: "invitations#show",   as: :accept_invitation
  post "invitations/:token", to: "invitations#accept", as: :claim_invitation

  root "home#index"
end
