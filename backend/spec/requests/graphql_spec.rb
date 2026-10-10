require "rails_helper"

RSpec.describe "GraphQL API" do
  # The dashboard is open to every role; a viewer has the least access.
  before { sign_in_as(:viewer) }

  def graphql(query, variables: {})
    post "/graphql", params: { query:, variables: }.to_json, headers: { "CONTENT_TYPE" => "application/json" }
    response.parsed_body
  end

  def error_messages(body) = body.fetch("errors", []).map { |e| e["message"] }

  describe "dashboard query" do
    before { create_insights_fixture }

    it "answers the whole dashboard in one request" do
      body = graphql(<<~GQL)
        {
          dashboard {
            headcount
            countriesCount
            currencies { currency headcount }
            headcountByCountry { countryCode countryName headcount }
            headcountByDepartment { department headcount }
            hiresByYear { year headcount }
            byDepartment: payStats(groupBy: DEPARTMENT, currency: USD) { group currency headcount min max avg median }
            distribution(currency: USD, buckets: 5) { from to count }
          }
        }
      GQL

      dashboard = body.dig("data", "dashboard")
      expect(body["errors"]).to be_nil
      expect(dashboard).to include("headcount" => 6, "countriesCount" => 4)
      expect(dashboard["currencies"].first).to eq("currency" => "USD", "headcount" => 3)
      expect(dashboard["headcountByCountry"].first).to eq("countryCode" => "US", "countryName" => "United States", "headcount" => 3)
      expect(dashboard["headcountByDepartment"].first).to eq("department" => "Engineering", "headcount" => 3)
      expect(dashboard["hiresByYear"]).to eq([ { "year" => 2020, "headcount" => 6 } ])
      expect(dashboard["byDepartment"]).to eq([
        { "group" => "Engineering", "currency" => "USD", "headcount" => 2, "min" => "100000.00", "max" => "120000.00", "avg" => "110000.00", "median" => "110000.00" },
        { "group" => "Sales", "currency" => "USD", "headcount" => 1, "min" => "90000.00", "max" => "90000.00", "avg" => "90000.00", "median" => "90000.00" }
      ])
      expect(dashboard["distribution"].sum { |b| b["count"] }).to eq(3)
    end

    it "applies the same filters to every widget" do
      body = graphql(<<~GQL, variables: { filters: { country: "US", department: "ENGINEERING" } })
        query($filters: DashboardFilters) {
          dashboard(filters: $filters) { headcount payStats(groupBy: JOB_TITLE) { group currency headcount } }
        }
      GQL

      expect(body.dig("data", "dashboard")).to eq(
        "headcount" => 2, "payStats" => [ { "group" => "Software Engineer", "currency" => "USD", "headcount" => 2 } ]
      )
    end

    it "accepts a list of values per filter (OR within a filter)" do
      body = graphql(<<~GQL, variables: { filters: { country: %w[DE FR], jobTitle: [ "HR Generalist", "Account Executive" ] } })
        query($filters: DashboardFilters) { dashboard(filters: $filters) { headcount } }
      GQL

      expect(body.dig("data", "dashboard", "headcount")).to eq(2)
    end

    it "accepts department names with spaces through the enum" do
      body = graphql('{ dashboard(filters: { department: CUSTOMER_SUPPORT }) { headcount } }')

      expect(body.dig("data", "dashboard", "headcount")).to eq(0)
    end

    it "lists the reference values (filters and currency choices) for the UI" do
      body = graphql("{ reference { countries { code name currency } departments currencies jobTitles } }")

      reference = body.dig("data", "reference")
      expect(reference["countries"].size).to eq(8)
      expect(reference["departments"]).to include("Customer Support")
      expect(reference["jobTitles"]).to eq([ "Account Executive", "Financial Analyst", "HR Generalist", "Software Engineer" ])
    end
  end

  describe "validation and limits" do
    it "rejects unknown filter values in the schema itself" do
      body = graphql('{ dashboard(filters: { country: XX }) { headcount } }')

      expect(error_messages(body).first).to match(/XX/)
      expect(body["data"]).to be_nil
    end

    it "rejects more than 50 values in one filter" do
      titles = Array.new(51) { |i| "Title #{i}" }
      body = graphql("query($f: DashboardFilters) { dashboard(filters: $f) { headcount } }", variables: { f: { jobTitle: titles } })

      expect(error_messages(body).join).to match(/jobTitle is too long \(maximum is 50\)/)
    end

    it "requires a currency for the salary distribution, so amounts are never mixed" do
      body = graphql("{ dashboard { distribution { count } } }")

      expect(error_messages(body).first).to match(/currency/)
    end

    it "keeps histogram buckets between 5 and 20" do
      [ 4, 21 ].each do |buckets|
        body = graphql("{ dashboard { distribution(currency: USD, buckets: #{buckets}) { count } } }")
        expect(error_messages(body)).to include("buckets must be between 5 and 20"), "buckets=#{buckets}"
      end
    end

    it "caps limit at 100 rows" do
      body = graphql("{ dashboard { payStats(groupBy: COUNTRY, limit: 101) { group } } }")

      expect(error_messages(body)).to include("limit must be between 1 and 100")
    end

    it "rejects queries that are too expensive (complexity above 200)" do
      body = graphql(<<~GQL)
        { dashboard {
            a: payStats(groupBy: COUNTRY, limit: 100) { group }
            b: payStats(groupBy: DEPARTMENT, limit: 100) { group }
            c: payStats(groupBy: JOB_TITLE, limit: 100) { group }
        } }
      GQL

      expect(error_messages(body).first).to match(/complexity of \d+, which exceeds max complexity of 200/)
    end

    it "rejects queries nested deeper than 8 levels" do
      body = graphql("{ __schema { types { fields { type { ofType { ofType { ofType { ofType { name } } } } } } } } }")

      expect(error_messages(body).first).to match(/exceeds max depth of 8/)
    end

    it "stops a slow query at the timeout instead of letting it run on" do
      slow_schema = Class.new(SalaryInsightsSchema) { use GraphQL::Schema::Timeout, max_seconds: 0.05 }
      allow(Insights::SummaryQuery).to receive(:new).and_wrap_original do |original, *args|
        sleep 0.1
        original.call(*args)
      end

      result = slow_schema.execute("{ dashboard { headcount countriesCount } }")

      expect(result["errors"].map { |e| e["message"] }.join).to match(/Timeout on Dashboard\./)
    end

    it "accepts a request without a variables key (e.g. from curl)" do
      post "/graphql", params: { query: "{ dashboard { headcount } }" }.to_json, headers: { "CONTENT_TYPE" => "application/json" }

      expect(response.parsed_body.dig("data", "dashboard", "headcount")).to eq(0)
    end

    it "reports a missing query clearly" do
      body = graphql(nil)

      expect(error_messages(body)).to include("No query string was present")
    end

    it "accepts only POST, and says so" do
      get "/graphql"

      expect(response).to have_http_status(:method_not_allowed)
      expect(response.headers["Allow"]).to eq("POST")
    end
  end

  describe "schema browsing (introspection)" do
    let(:introspection) { "{ __schema { queryType { name } } }" }

    it "is available when GraphiQL is enabled (local and development)" do
      allow(Rails.configuration.x).to receive(:graphiql_enabled).and_return(true)

      expect(graphql(introspection).dig("data", "__schema", "queryType", "name")).to eq("Query")
    end

    it "is switched off when GraphiQL is disabled (the default for real deployments)" do
      allow(Rails.configuration.x).to receive(:graphiql_enabled).and_return(false)

      body = graphql(introspection)
      expect(body.dig("data", "__schema")).to be_nil
      expect(error_messages(body).first).to match(/__schema/)
    end
  end
end
