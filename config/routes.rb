Rails.application.routes.draw do
  resource :session
  resource :registration, only: [ :new, :create ]
  resources :passwords, param: :token
  resources :users, only: [ :index, :create, :destroy ]

  # Admin / dashboard (Hotwire, session-authenticated)
  resources :inverters
  resource :mqtt_config, only: [ :show, :edit, :update ]
  resource :tariff, only: [ :show, :edit, :update ]
  resources :api_tokens, only: [ :index, :create, :destroy ]

  # Token-authenticated REST API for clients (e.g. a native macOS app).
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resources :inverters, only: [ :index, :show ] do
        resources :readings, only: [ :index ]
      end
    end
  end

  # Health check for load balancers / uptime monitors.
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA: web app manifest + service worker (installable dashboard).
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest, defaults: { format: "json" }
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker, defaults: { format: "js" }

  root "dashboards#show"
end
