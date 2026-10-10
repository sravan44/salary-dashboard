require "rails_helper"

RSpec.describe "Reference data API" do
  it "returns the values the UI needs for its filter dropdowns" do
    create(:employee, job_title: "Staff Engineer")
    create(:employee, job_title: "Account Executive")
    create(:employee, job_title: "Staff Engineer")

    get "/api/v1/reference"

    expect(response).to have_http_status(:ok)
    body = response.parsed_body["data"]
    expect(body["countries"].first).to eq("code" => "US", "name" => "United States", "currency" => "USD")
    expect(body["countries"].size).to eq(8)
    expect(body["currencies"]).to eq(%w[USD INR GBP EUR CAD AUD SGD])
    expect(body["departments"]).to include("Engineering", "People")
    expect(body["statuses"]).to eq(%w[active terminated])
    expect(body["job_titles"]).to eq([ "Account Executive", "Staff Engineer" ])
  end
end
