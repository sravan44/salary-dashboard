require "rails_helper"

# In the single production container, Rails serves the built React app as well as /api.
RSpec.describe "Serving the frontend from Rails" do
  let(:index) { Pathname(Dir.mktmpdir).join("index.html") }

  around do |example|
    original = Rails.configuration.x.frontend_index
    Rails.configuration.x.frontend_index = index
    example.run
  ensure
    Rails.configuration.x.frontend_index = original
  end

  context "when the frontend has been built" do
    before { index.write("<!doctype html><title>ACME Salary Insights</title><div id=root></div>") }

    it "serves the app at the root" do
      get "/"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/html")
      expect(response.body).to include("<title>ACME Salary Insights</title>")
    end

    it "serves the app for client-side routes, so bookmarked URLs work after a refresh" do
      get "/employees", params: { country: "IN", page: 2 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("id=root")
    end

    it "tells browsers to revalidate the page, so a new deploy is picked up immediately" do
      get "/employees"

      expect(response.headers["Cache-Control"]).to eq("no-cache")
    end

    it "does not answer a missing asset file with the app page" do
      get "/assets/missing-abc123.js"

      expect(response).to have_http_status(:not_found)
    end

    it "keeps unknown API paths as JSON 404s instead of returning the app page" do
      get "/api/v1/does-not-exist"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["error"]).to include("code" => "not_found")
    end
  end

  describe "GraphiQL at /graphiql" do
    let(:graphiql) { Pathname(Dir.mktmpdir).join("graphiql.html") }

    around do |example|
      original = Rails.configuration.x.frontend_graphiql
      Rails.configuration.x.frontend_graphiql = graphiql
      example.run
    ensure
      Rails.configuration.x.frontend_graphiql = original
    end

    it "serves the GraphiQL page when enabled" do
      graphiql.write("<!doctype html><title>GraphiQL</title>")
      allow(Rails.configuration.x).to receive(:graphiql_enabled).and_return(true)

      get "/graphiql"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<title>GraphiQL</title>")
      expect(response.headers["Cache-Control"]).to eq("no-cache")
    end

    it "is not available when disabled (the default for real deployments)" do
      graphiql.write("<!doctype html><title>GraphiQL</title>")
      allow(Rails.configuration.x).to receive(:graphiql_enabled).and_return(false)

      get "/graphiql"

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include("GraphiQL</title>")
    end
  end

  it "explains a missing build instead of failing obscurely" do
    get "/employees"

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("Frontend not built")
  end
end
