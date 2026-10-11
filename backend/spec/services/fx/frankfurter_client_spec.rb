require "rails_helper"

# The HTTP layer is replaced by a stub: these specs never touch the network.
RSpec.describe Fx::FrankfurterClient do
  let(:client) { described_class.new(base_url: "https://fx.example") }

  def stub_http(response = nil, error: nil)
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start) do |host, port, **options, &block|
      @connection = { host:, port:, **options }
      raise error if error

      allow(http).to receive(:get) { |path| @path = path; response }
      block.call(http)
    end
  end

  def ok(body) = instance_double(Net::HTTPOK, body: body.to_json).tap { |r| allow(r).to receive(:is_a?) { |klass| klass == Net::HTTPSuccess } }

  it "requests the latest rates for the base and currencies, with short timeouts, and parses date and rates exactly" do
    stub_http(ok("amount" => 1.0, "base" => "EUR", "date" => "2026-10-09", "rates" => { "USD" => 1.1, "INR" => 92.4 }))

    result = client.latest(base: "EUR", symbols: %w[USD INR])

    expect(@path).to eq("/latest?from=EUR&to=USD%2CINR")
    expect(@connection).to include(host: "fx.example", port: 443, use_ssl: true, open_timeout: 3, read_timeout: 5)
    expect(result).to eq(date: Date.new(2026, 10, 9), rates: { "USD" => BigDecimal("1.1"), "INR" => BigDecimal("92.4") })
  end

  it "raises ProviderError for an HTTP error status" do
    response = instance_double(Net::HTTPServiceUnavailable, code: "503", body: "")
    allow(response).to receive(:is_a?).and_return(false)
    stub_http(response)

    expect { client.latest(base: "EUR", symbols: [ "USD" ]) }.to raise_error(Fx::ProviderError, "Frankfurter answered HTTP 503")
  end

  it "raises ProviderError for an unexpected body or a different base" do
    stub_http(ok("base" => "USD", "date" => "2026-10-09", "rates" => {}))
    expect { client.latest(base: "EUR", symbols: [ "USD" ]) }.to raise_error(Fx::ProviderError, /unexpected response/)

    stub_http(instance_double(Net::HTTPOK, body: "<html>").tap { |r| allow(r).to receive(:is_a?) { |klass| klass == Net::HTTPSuccess } })
    expect { client.latest(base: "EUR", symbols: [ "USD" ]) }.to raise_error(Fx::ProviderError, /unexpected response/)
  end

  describe "redirects (the provider moved: the live refresh got HTTP 301)" do
    def redirect(location, code = "301")
      instance_double(Net::HTTPMovedPermanently, code:, body: "").tap do |r|
        allow(r).to receive(:is_a?) { |klass| klass == Net::HTTPRedirection }
        allow(r).to receive(:[]).with("location").and_return(location)
      end
    end

    # Answers each request in turn and records where it went.
    def stub_sequence(*responses)
      @requests = []
      allow(Net::HTTP).to receive(:start) do |host, port, **options, &block|
        http = instance_double(Net::HTTP)
        allow(http).to receive(:get) { |path| @requests << "#{options[:use_ssl] ? 'https' : 'http'}://#{host}:#{port}#{path}"; responses.shift }
        block.call(http)
      end
    end

    let(:rates) { ok("base" => "EUR", "date" => "2026-10-09", "rates" => { "USD" => 1.1 }) }

    it "follows a redirect to the provider's new address and keeps the query" do
      stub_sequence(redirect("https://api.frankfurter.dev/v1/latest?from=EUR&to=USD"), rates)

      expect(client.latest(base: "EUR", symbols: [ "USD" ])[:rates]).to eq("USD" => BigDecimal("1.1"))
      expect(@requests).to eq([ "https://fx.example:443/latest?from=EUR&to=USD", "https://api.frankfurter.dev:443/v1/latest?from=EUR&to=USD" ])
    end

    it "follows a relative redirect on the same host" do
      stub_sequence(redirect("/v1/latest?from=EUR&to=USD", "308"), rates)

      client.latest(base: "EUR", symbols: [ "USD" ])
      expect(@requests.last).to eq("https://fx.example:443/v1/latest?from=EUR&to=USD")
    end

    it "refuses to follow a redirect to plain http" do
      stub_sequence(redirect("http://insecure.example/latest"))

      expect { client.latest(base: "EUR", symbols: [ "USD" ]) }.to raise_error(Fx::ProviderError, "refused a redirect to a non-HTTPS address")
    end

    it "gives up after 3 redirects" do
      stub_sequence(*Array.new(4) { redirect("https://fx.example/again") })

      expect { client.latest(base: "EUR", symbols: [ "USD" ]) }.to raise_error(Fx::ProviderError, "too many redirects from Frankfurter")
    end

    it "uses the provider's current address by default, so no redirect is needed" do
      stub_sequence(rates)

      described_class.new.latest(base: "EUR", symbols: [ "USD" ])
      expect(@requests).to eq([ "https://api.frankfurter.dev:443/v1/latest?from=EUR&to=USD" ])
    end

    it "keeps a path in the configured address (e.g. FX_PROVIDER_URL=https://api.frankfurter.dev/v1)" do
      stub_sequence(rates)

      described_class.new(base_url: "https://api.frankfurter.dev/v1/").latest(base: "EUR", symbols: [ "USD" ])
      expect(@requests).to eq([ "https://api.frankfurter.dev:443/v1/latest?from=EUR&to=USD" ])
    end
  end

  it "raises ProviderError when the provider cannot be reached" do
    stub_http(error: Net::OpenTimeout)

    expect { client.latest(base: "EUR", symbols: [ "USD" ]) }.to raise_error(Fx::ProviderError, /could not reach Frankfurter/)
  end
end
