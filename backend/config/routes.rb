Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  post "graphql", to: "graphql#execute"
  match "graphql", to: "graphql#method_not_allowed", via: %i[get put patch delete]
  get "graphiql", to: "frontend#graphiql"

  namespace :api do
    namespace :v1 do
      resource :session, only: %i[show create destroy]
      resource :password, only: :update                      # change my own password (signed in)
      resource :password_reset, only: %i[create update]      # forgot password; use a reset or set-password link
      resources :users, only: %i[index create update] do
        patch :password, action: :set_password, on: :member
        post :password_links, action: :send_password_links, on: :collection
      end
      resources :employees, only: %i[index show create update] do
        resources :compensations, only: %i[index create]
        resources :versions, only: :index
      end
      resource :reference, only: :show
      resources :exchange_rates, only: :index do                # Admins: cached rates, and fetch fresh ones now
        post :sync, on: :collection
      end
    end
    match "*path", to: "v1/base#route_not_found", via: :all
  end

  # Demo email inbox (the emails the app "sent": set-password and reset links). Signed-in Admins only, and only
  # where EMAIL_INBOX is on; for anyone else these routes don't exist (pages fall through to the React app).
  constraints(EmailInboxConstraint) { mount LetterOpenerWeb::Engine, at: "/letter_opener" }

  # Everything else is a client-side route of the React app, except paths that look like files.
  root "frontend#show"
  get "*path", to: "frontend#show", constraints: ->(request) { File.extname(request.path).empty? }
end
