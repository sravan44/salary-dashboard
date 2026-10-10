Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  post "graphql", to: "graphql#execute"
  match "graphql", to: "graphql#method_not_allowed", via: %i[get put patch delete]
  get "graphiql", to: "frontend#graphiql"

  namespace :api do
    namespace :v1 do
      resource :session, only: %i[show create destroy]
      resources :users, only: %i[index create update]
      resources :employees, only: %i[index show create update]
      resource :reference, only: :show
    end
    match "*path", to: "v1/base#route_not_found", via: :all
  end

  # Everything else is a client-side route of the React app, except paths that look like files.
  root "frontend#show"
  get "*path", to: "frontend#show", constraints: ->(request) { File.extname(request.path).empty? }
end
