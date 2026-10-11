require "rails_helper"

RSpec.describe "Salary history API" do
  include ActiveSupport::Testing::TimeHelpers

  around { |example| travel_to(Date.new(2026, 10, 10)) { example.run } }

  before { sign_in_as(:hr_manager, email: "hr@acme.example") }

  let(:employee) { create(:employee, full_name: "Asha Rao", hire_date: Date.new(2023, 4, 1)) }
  let!(:history) do
    [
      create(:compensation, employee:, amount: "1800000", currency: "INR", effective_from: Date.new(2023, 4, 1), effective_to: Date.new(2024, 3, 31), reason: "hire", revised_by: "seed"),
      create(:compensation, employee:, amount: "2000000", currency: "INR", effective_from: Date.new(2024, 4, 1), effective_to: Date.new(2025, 6, 30), reason: "annual_review", notes: "Strong year", revised_by: "seed"),
      create(:compensation, employee:, amount: "98000", currency: "USD", effective_from: Date.new(2025, 7, 1), reason: "market_adjustment", revised_by: "seed")
    ]
  end

  describe "GET /api/v1/employees/:id/compensations" do
    it "lists the full history newest first, with % change only when the currency is the same" do
      get "/api/v1/employees/#{employee.id}/compensations"
      expect(response.parsed_body).not_to have_key("meta") # no conversion unless asked for

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to eq([
        { "id" => history[2].id, "amount" => "98000.00", "currency" => "USD", "effective_from" => "2025-07-01", "effective_to" => nil,
          "current" => true, "reason" => "market_adjustment", "notes" => nil, "revised_by" => "seed", "change_percent" => nil },
        { "id" => history[1].id, "amount" => "2000000.00", "currency" => "INR", "effective_from" => "2024-04-01", "effective_to" => "2025-06-30",
          "current" => false, "reason" => "annual_review", "notes" => "Strong year", "revised_by" => "seed", "change_percent" => "11.11" },
        { "id" => history[0].id, "amount" => "1800000.00", "currency" => "INR", "effective_from" => "2023-04-01", "effective_to" => "2024-03-31",
          "current" => false, "reason" => "hire", "notes" => nil, "revised_by" => "seed", "change_percent" => nil }
      ])
    end

    describe "in a reporting currency (?report=)" do
      it "adds the converted amount to every record, and the rates, date and source used" do
        store_rates(Date.new(2026, 10, 9), "USD" => "1.10", "INR" => "92.40")
        get "/api/v1/employees/#{employee.id}/compensations", params: { report: "USD" }

        body = response.parsed_body
        expect(body["data"].map { |r| [ r["amount"], r["currency"], r["converted"] ] }).to eq([
          [ "98000.00", "USD", { "amount" => "98000.00", "currency" => "USD" } ],
          [ "2000000.00", "INR", { "amount" => "23809.52", "currency" => "USD" } ],
          [ "1800000.00", "INR", { "amount" => "21428.57", "currency" => "USD" } ]
        ])
        expect(body["data"].map { |r| r["change_percent"] }).to eq([ nil, "11.11", nil ]) # still from the original amounts
        expect(body["meta"]["conversion"]).to eq(
          "to" => "USD", "available" => true, "rate_date" => "2026-10-09", "source" => "ECB reference rates via Frankfurter",
          "stale" => false, "rates" => [ { "currency" => "INR", "rate" => "0.0119047619" }, { "currency" => "USD", "rate" => "1.0" } ],
          "missing" => []
        )
      end

      it "leaves an amount unconverted, and names the currency, when there is no rate for it" do
        store_rates(Date.new(2026, 10, 9), "USD" => "1.10")
        get "/api/v1/employees/#{employee.id}/compensations", params: { report: "USD" }

        expect(response.parsed_body["data"].map { |r| r["converted"] }).to eq([ { "amount" => "98000.00", "currency" => "USD" }, nil, nil ])
        expect(response.parsed_body["meta"]["conversion"]["missing"]).to eq([ "INR" ])
      end

      it "says so when no rates have been fetched" do
        get "/api/v1/employees/#{employee.id}/compensations", params: { report: "USD" }

        expect(response.parsed_body["meta"]["conversion"]).to include("available" => false, "missing" => %w[INR USD])
        expect(response.parsed_body["data"].map { |r| r["converted"] }).to all(be_nil)
      end

      it "rejects an unsupported currency" do
        get "/api/v1/employees/#{employee.id}/compensations", params: { report: "XYZ" }

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body["error"]["details"]).to eq("report" => [ "must be one of: USD, INR, GBP, EUR, CAD, AUD, SGD" ])
      end

      it "leaves the stored salaries unchanged" do
        store_rates(Date.new(2026, 10, 9), "USD" => "1.10", "INR" => "92.40")

        expect { get "/api/v1/employees/#{employee.id}/compensations", params: { report: "USD" } }
          .not_to(change { Compensation.pluck(:amount, :currency).sort })
      end
    end

    it "returns 404 for an unknown employee" do
      get "/api/v1/employees/0/compensations"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/employees/:id/compensations" do
    let(:payload) { { compensation: { amount: "105000", currency: "USD", effective_from: "2026-10-01", reason: "promotion", notes: "Lead" } } }

    it "records the change and returns the new current record with % change" do
      post "/api/v1/employees/#{employee.id}/compensations", params: payload, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["data"]).to include(
        "amount" => "105000.00", "currency" => "USD", "effective_from" => "2026-10-01", "current" => true,
        "reason" => "promotion", "revised_by" => "hr@acme.example", "change_percent" => "7.14"
      )
      expect(history[2].reload.effective_to).to eq(Date.new(2026, 9, 30))
    end

    it "returns 422 with field errors and leaves history untouched" do
      payload[:compensation].merge!(effective_from: "2025-07-01", amount: "-1")

      expect { post "/api/v1/employees/#{employee.id}/compensations", params: payload, as: :json }.not_to change(Compensation, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]["details"].keys).to contain_exactly("effective_from", "amount")
      expect(history[2].reload.effective_to).to be_nil
    end
  end

  describe "GET /api/v1/employees/:id/versions" do
    it "shows who changed what on the employee and their salary records, newest first" do
      patch "/api/v1/employees/#{employee.id}", params: { employee: { job_title: "Staff Engineer" } }, as: :json
      post "/api/v1/employees/#{employee.id}/compensations",
           params: { compensation: { amount: "105000", currency: "USD", effective_from: "2026-10-01", reason: "promotion" } }, as: :json

      get "/api/v1/employees/#{employee.id}/versions"

      entries = response.parsed_body["data"]
      expect(entries.first(3).map { |e| [ e["item_type"], e["event"], e["whodunnit"] ] }).to eq([
        [ "Compensation", "create", "hr@acme.example" ],
        [ "Compensation", "update", "hr@acme.example" ],
        [ "Employee", "update", "hr@acme.example" ]
      ])
      expect(entries[1]["changes"]).to eq("effective_to" => [ nil, "2026-09-30" ])
      expect(entries[2]["changes"]).to eq("job_title" => [ "Software Engineer", "Staff Engineer" ])
      expect(entries.first.keys).to contain_exactly("id", "item_type", "item_id", "event", "changes", "whodunnit", "created_at")
    end
  end
end
