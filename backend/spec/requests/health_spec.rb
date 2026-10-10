require "rails_helper"

RSpec.describe "Health check" do
  it "reports the app as up so the platform can route traffic to it" do
    get "/up"

    expect(response).to have_http_status(:ok)
  end
end
