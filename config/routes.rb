Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"

  # Solid Queue web interface
  mount MissionControl::Jobs::Engine, at: "/jobs"

  resources :coolify_teams, only: [:new, :create, :destroy]
  
  # Coolify sync endpoint
  post "sync", to: "sync#create"

  # Manual metrics trigger
  post "metrics/collect_now", to: "metrics#collect_now"

  # Server SSH key entry
  post "servers/:id/private_key", to: "private_keys#upsert", as: :server_private_key
  post "servers/:id/ssh_test", to: "metrics#ssh_test", as: :server_ssh_test
  post "servers/:id/collect_stats", to: "metrics#collect_server_stats", as: :server_collect_stats

  resources :private_keys, only: [:edit, :update]
  
  # Resources detail pages
  resources :resources, only: [:show]
  
  # Server detail pages
  resources :servers, only: [:show]
end
