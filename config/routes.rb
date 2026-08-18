require 'sidekiq/web'

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  mount Sidekiq::Web => "/sidekiq"

  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  devise_scope :user do
    post   "/login",  to: "sessions#create"
    delete "/logout", to: "sessions#destroy"
  end

  devise_for :users,
             skip: [ :sessions ],
             controllers: {
               registrations: "registrations",
               passwords:     "passwords"
             }

  namespace :api do
    namespace :v1 do
      get  "me", to: "users#me"
      resources :series do
        resources :episodes do
          member do
            post :upload,  action: :create_upload
            get  :playback
            post :unlock
          end
        end
      end

      scope :coins do
        get  "/",              to: "coins#balance",        as: :coin_balance
        post "/purchase",      to: "coins#purchase",       as: :coin_purchase
        post "/purchase/verify", to: "coins#verify_purchase", as: :coin_purchase_verify
        post "/reward",        to: "coins#reward",         as: :coin_reward
        get  "/reward_status", to: "coins#reward_status",  as: :coin_reward_status
      end

      resource :subscriptions, only: %i[show create destroy] do
        collection do
          post :checkout
          post :verify_subscription
        end
      end

      scope :watch_progress do
        get   "/", to: "watch_progress#index",  as: :watch_progress
        patch "/", to: "watch_progress#update", as: :update_watch_progress
      end
    end
  end

    post "/webhooks/mux", to: "webhooks/mux#create"
    post "/webhooks/stripe", to: "webhooks/stripe#create"
end
