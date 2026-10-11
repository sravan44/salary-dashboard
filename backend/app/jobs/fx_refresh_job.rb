# Keeps the cached exchange rates in sync (scheduled in config/recurring.yml, weekdays after the ECB
# publishes). A provider failure is retried twice, 30 minutes apart; after that the cached rates are
# left as they were, and the dashboard flags them as stale once they are more than 7 days old.
class FxRefreshJob < ApplicationJob
  ATTEMPTS = 3

  queue_as :default

  # No jitter: one daily job, and a predictable retry time is easier to reason about.
  retry_on Fx::ProviderError, wait: 30.minutes, attempts: ATTEMPTS, jitter: 0 do |_job, error|
    Rails.logger.error("FX refresh gave up after #{ATTEMPTS} attempts: #{error.message}. Cached rates are unchanged.")
  end

  def perform
    result = Fx::Refresh.call
    Rails.logger.info("FX refresh stored #{result[:stored]} rates for #{result[:date].iso8601} (#{Fx::SOURCE})")
  end
end
