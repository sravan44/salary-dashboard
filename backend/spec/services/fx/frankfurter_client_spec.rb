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

  def ok(body) = instance_double(Net::HTTPOK, body: body.to_json).tap { |r| allow(r).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true) }

  it "requests the latest rates for the base and currencies, with short timeouts, and parses date and rates exactly" do
    stub_http(ok("amount" => 1.0, "base" => "EUR", "date" => "2026-10-09", "rates" => { "USD" => 1.1, "INR" => 92.4 }))

    result = client.latest(base: "EUR", symbols: %w[USD INR])

    expect(@path).to eq("/latest?from=EUR&to=USD%2CINR")
    expect(@connection).to include(host: "fx.example", port: 443, use_ssl: true, open_timeout: 3, read_timeout: 5)
    expect(result).to eq(date: Date.new(2026, 10, 9), rates: { "USD" => BigDecimal("1.1"), "INR" => BigDecimal("92.4") })
  end

  it "raises ProviderError for an HTTP error status" do
    response = instance_double(Net::HTTPServiceUnavailable, code: "503", body: "")
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
    stub_http(response)

    expect { client.latest(base: "EUR", symbols: [ "USD" ]) }.to raise_error(Fx::ProviderError, "Frankfurter answered HTTP 503")
  end

  it "raises ProviderError for an unexpected body or a different base" do
    stub_http(ok("base" => "USD", "date" => "2026-10-09", "rates" => {}))
    expect { client.latest(base: "EUR", symbols: [ "USD" ]) }.to raise_error(Fx::ProviderError, /unexpected response/)

    stub_http(instance_double(Net::HTTPOK, body: "<html>").tap { |r| allow(r).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true) })
    expect { client.latest(base: "EUR", symbols: [ "USD" ]) }.to raise_error(Fx::ProviderError, /unexpected response/)
  end

  it "raises ProviderError when the provider cannot be reached" do
    stub_http(error: Net::OpenTimeout)

    expect { client.latest(base: "EUR", symbols: [ "USD" ]) }.to raise_error(Fx::ProviderError, /could not reach Frankfurter/)
  end
end
