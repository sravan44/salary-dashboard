require "net/http"

module Fx
  # Fetches the latest reference rates from Frankfurter (https://frankfurter.dev): one request for
  # all currencies. Every failure (network, HTTP status, unexpected body) becomes a ProviderError.
  class FrankfurterClient
    # The old https://api.frankfurter.app now answers 301 to this address (seen in the live refresh).
    DEFAULT_URL = "https://api.frankfurter.dev/v1".freeze
    MAX_REDIRECTS = 3
    NETWORK_ERRORS = [ Timeout::Error, SystemCallError, SocketError, IOError, OpenSSL::SSL::SSLError ].freeze

    def initialize(base_url: ENV.fetch("FX_PROVIDER_URL", DEFAULT_URL), open_timeout: 3, read_timeout: 5)
      @uri = URI(base_url)
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    # => { date: Date, rates: { "USD" => BigDecimal, ... } } where 1 base = rate quote.
    def latest(base:, symbols:)
      uri = URI("#{@uri.to_s.chomp('/')}/latest?#{URI.encode_www_form(from: base, to: symbols.join(','))}")
      response = follow_redirects(uri)
      raise ProviderError, "Frankfurter answered HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      parse(response.body, base)
    rescue *NETWORK_ERRORS => e
      raise ProviderError, "could not reach Frankfurter (#{e.class})"
    end

    private

    # The provider has moved before (the old address now answers 301), so a few HTTPS-only
    # redirects are followed, relative or absolute.
    def follow_redirects(uri)
      (MAX_REDIRECTS + 1).times do
        response = get(uri)
        return response unless response.is_a?(Net::HTTPRedirection)

        uri = URI.join(uri.to_s, response["location"])
        raise ProviderError, "refused a redirect to a non-HTTPS address" unless uri.scheme == "https"
      end
      raise ProviderError, "too many redirects from Frankfurter"
    end

    def get(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                          open_timeout: @open_timeout, read_timeout: @read_timeout) { |http| http.get(uri.request_uri) }
    end

    def parse(body, base)
      data = JSON.parse(body)
      raise KeyError, "base" unless data.fetch("base") == base

      { date: Date.iso8601(data.fetch("date")), rates: data.fetch("rates").transform_values { |rate| BigDecimal(rate.to_s) } }
    rescue JSON::ParserError, KeyError, TypeError, Date::Error, ArgumentError, NoMethodError
      raise ProviderError, "unexpected response from Frankfurter"
    end
  end
end
