# Serves the built React app (one container: Rails serves the SPA and /api on the same origin).
# Hashed assets under /assets are served by the static file server with long-lived caching.
# index.html is served here with "no-cache", so a new deploy is picked up immediately.
class FrontendController < ActionController::API
  def show
    index = Rails.configuration.x.frontend_index
    unless index.exist?
      return render plain: "Frontend not built. Run `npm run build` in frontend/ (the Docker image does this).", status: :not_found
    end

    response.headers["Cache-Control"] = "no-cache"
    send_file index, type: "text/html", disposition: "inline"
  end
end
