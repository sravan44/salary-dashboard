module Fx
  # Fetches the latest reference rates once and caches them. Safe to re-run: a second fetch for the
  # same rate date replaces that day's rows. If the provider fails, the cache is left as it was.
  class Refresh
    def self.call(client: FrankfurterClient.new, now: Time.current) = new(client, now).call

    def initialize(client, now)
      @client = client
      @now = now
    end

    def call
      currencies = Acme::Reference.currencies - [ BASE ]
      result = @client.latest(base: BASE, symbols: currencies)
      rows = result[:rates].slice(*currencies).select { |_, rate| rate.positive? }.map do |quote, rate|
        { base: BASE, quote:, rate_date: result[:date], rate:, source: SOURCE, fetched_at: @now, created_at: @now, updated_at: @now }
      end
      FxRate.upsert_all(rows, unique_by: %i[base quote rate_date], update_only: %i[rate source fetched_at]) if rows.any?
      { date: result[:date], stored: rows.size }
    end
  end
end
