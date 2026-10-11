require "net/http"

module Fx
  # Fetches the latest reference rates from Frankfurter (https://frankfurter.dev): one request for
  # all currencies. Every failure (network, HTTP status, unexpected body) becomes a ProviderError.
  class FrankfurterClient
    DEFAULT_URL = "https://api.frankfurter.app".freeze
    NETWORK_ERRORS = [ Timeout::Error, SystemCallError, SocketError, IOError, OpenSSL::SSL::SSLError ].freeze

    def initialize(base_url: ENV.fetch("FX_PROVIDER_URL", DEFAULT_URL), open_timeout: 3, read_timeout: 5)
      @uri = URI(base_url)
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    # => { date: Date, rates: { "USD" => BigDecimal, ... } } where 1 base = rate quote.
    def latest(base:, symbols:)
      path = "/latest?#{URI.encode_www_form(from: base, to: symbols.join(','))}"
      response = Net::HTTP.start(@uri.host, @uri.port, use_ssl: @uri.scheme == "https",
                                                       open_timeout: @open_timeout, read_timeout: @read_timeout) { |http| http.get(path) }
      raise ProviderError, "Frankfurter answered HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      parse(response.body, base)
    rescue *NETWORK_ERRORS => e
      raise ProviderError, "could not reach Frankfurter (#{e.class})"
    end

    private

    def parse(body, base)
      data = JSON.parse(body)
      raise KeyError, "base" unless data.fetch("base") == base

      { date: Date.iso8601(data.fetch("date")), rates: data.fetch("rates").transform_values { |rate| BigDecimal(rate.to_s) } }
    rescue JSON::ParserError, KeyError, TypeError, Date::Error, ArgumentError, NoMethodError
      raise ProviderError, "unexpected response from Frankfurter"
    end
  end
end
