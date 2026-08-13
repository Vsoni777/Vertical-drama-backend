Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  devise_scope :user do
    post '/login', to: 'sessions#create'
    delete '/logout', to: 'sessions#destroy'
  end

  devise_for :users,
            skip: [:sessions],
            controllers: {
              registrations: 'registrations'
            }
  namespace :api do
    namespace :v1 do
      resources :series do
        resources :episodes
      end
    end
  end

end
