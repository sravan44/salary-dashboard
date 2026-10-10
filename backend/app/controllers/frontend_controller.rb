# Serves the built React app (one container: Rails serves the SPA and /api on the same origin).
# Hashed assets under /assets are served by the static file server with long-lived caching.
# HTML entry pages are served here with "no-cache", so a new deploy is picked up immediately.
class FrontendController < ActionController::API
  def show
    serve Rails.configuration.x.frontend_index
  end

  # GraphiQL, the in-browser GraphQL explorer: only where enabled (local/dev by default).
  def graphiql
    return head(:not_found) unless Rails.configuration.x.graphiql_enabled

    serve Rails.configuration.x.frontend_graphiql
  end

  private

  def serve(page)
    unless page.exist?
      return render plain: "Frontend not built. Run `npm run build` in frontend/ (the Docker image does this).", status: :not_found
    end

    response.headers["Cache-Control"] = "no-cache"
    send_file page, type: "text/html", disposition: "inline"
  end
end
