module Api
  module V1
    # Admins: the cached reference rates (GET) and an on-demand refresh (POST sync), alongside the
    # scheduled weekday refresh. A provider failure leaves the cache exactly as it was.
    class ExchangeRatesController < BaseController
      # Per-process store: enough for one app container.
      RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

      require_permission :manage_users
      rate_limit to: 5, within: 10.minutes, only: :sync, store: RATE_LIMIT_STORE, name: "sync",
                 with: -> { render_error(:too_many_requests, "too_many_requests", "Rates were synced several times just now. Try again in a few minutes.") }

      def index
        render json: { data: Fx::LatestRatesQuery.call }
      end

      def sync
        result = Fx::Refresh.call
        render json: { data: Fx::LatestRatesQuery.call.merge(stored: result[:stored]) }
      rescue Fx::ProviderError => e
        Rails.logger.warn("FX sync failed: #{e.message}. Cached rates are unchanged.")
        render_error(:bad_gateway, "provider_unavailable", "Couldn't reach the rate provider, so the cached rates are unchanged. Try again later.")
      end
    end
  end
end
