Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # PIN auth
  resource :session, only: %i[new create destroy]

  # Listings
  resources :listings, except: %i[index] do
    member do
      patch :toggle_status
      patch :update_notes
      patch :toggle_favorite
    end
    collection do
      get :resolve_source
    end
  end

  root "listings#index"
end
