require "rails_helper"

RSpec.describe Acme::Reference do
  it "supports eight countries, each with an ISO-4217 default currency" do
    expect(described_class.country_codes).to eq(%w[US IN GB DE FR CA AU SG])
    expect(described_class.currency_for("IN")).to eq("INR")
    expect(described_class.currency_for("FR")).to eq("EUR")
  end

  it "lists each supported currency once, even when countries share it" do
    expect(described_class.currencies).to eq(%w[USD INR GBP EUR CAD AUD SGD])
  end

  it "has no currency for an unsupported country" do
    expect(described_class.currency_for("XX")).to be_nil
  end

  it "lists the departments HR reports on" do
    expect(described_class.departments).to include("Engineering", "People", "Sales")
  end
end
