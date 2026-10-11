require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module SalaryInsights
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true
    # Sign-in uses an HttpOnly cookie, so the cookie middleware is added back (no session store).
    config.middleware.use ActionDispatch::Cookies

    # The built React app's entry page (see FrontendController). Kept outside public/ so it is
    # never served with the long-lived cache headers used for hashed assets.
    # Links in emails (set-password, reset) point at the app's public address: APP_URL, else https://APP_HOST
    # (the domain Caddy serves), else the local app.
    app_host = ENV["APP_HOST"].to_s
    config.x.app_url = ENV["APP_URL"].presence || (app_host.match?(/\A[a-z0-9.-]+\z/i) ? "https://#{app_host}" : "http://localhost:3000")

    config.x.frontend_index = Rails.root.join(ENV.fetch("FRONTEND_INDEX", "frontend/index.html"))
    config.x.frontend_graphiql = Rails.root.join(ENV.fetch("FRONTEND_GRAPHIQL", "frontend/graphiql.html"))

    # GraphiQL (/graphiql) and GraphQL schema browsing: on for local/dev, off for real deployments
    # unless GRAPHIQL_ENABLED=true.
    # The demo email inbox (letter_opener_web, Admins only): on locally, opt-in elsewhere with EMAIL_INBOX=true.
    config.x.email_inbox = ENV.fetch("EMAIL_INBOX") { Rails.env.local?.to_s } == "true"
    config.x.graphiql_enabled = ENV.fetch("GRAPHIQL_ENABLED") { Rails.env.local?.to_s } == "true"
  end
end
