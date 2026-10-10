require "rails_helper"

# Who may call what. Every API and GraphQL request needs a signed-in user; roles decide the rest.
RSpec.describe "Authorization" do
  let!(:employee) { create(:employee) }

  REQUESTS = {
    "directory" => [ :get, "/api/v1/employees" ],
    "employee profile" => [ :get, "/api/v1/employees/:id" ],
    "create employee" => [ :post, "/api/v1/employees", { employee: { full_name: "" } } ],
    "edit employee" => [ :patch, "/api/v1/employees/:id", { employee: { full_name: "New" } } ],
    "salary history" => [ :get, "/api/v1/employees/:id/compensations" ],
    "record salary change" => [ :post, "/api/v1/employees/:id/compensations", { compensation: { amount: "" } } ],
    "audit trail" => [ :get, "/api/v1/employees/:id/versions" ],
    "reference data" => [ :get, "/api/v1/reference" ],
    "dashboard (GraphQL)" => [ :post, "/graphql", { query: "{ dashboard { headcount } }" } ],
    "list users" => [ :get, "/api/v1/users" ],
    "create user" => [ :post, "/api/v1/users", { user: { email: "" } } ],
    "change roles" => [ :patch, "/api/v1/users/:user_id", { user: { roles: [ "viewer" ] } } ]
  }.freeze

  # Expected status per request: signed out, viewer, hr_manager, admin.
  EXPECTED = {
    "directory" => [ 401, 403, 200, 403 ],
    "employee profile" => [ 401, 403, 200, 403 ],
    "create employee" => [ 401, 403, 422, 403 ],
    "edit employee" => [ 401, 403, 200, 403 ],
    "salary history" => [ 401, 403, 200, 403 ],
    "record salary change" => [ 401, 403, 422, 403 ],
    "audit trail" => [ 401, 403, 200, 403 ],
    "reference data" => [ 401, 200, 200, 200 ],
    "dashboard (GraphQL)" => [ 401, 200, 200, 200 ],
    "list users" => [ 401, 403, 403, 200 ],
    "create user" => [ 401, 403, 403, 422 ],
    "change roles" => [ 401, 403, 403, 200 ]
  }.freeze

  def call(name, other_user)
    verb, path, body = REQUESTS.fetch(name)
    path = path.sub(":id", employee.id.to_s).sub(":user_id", other_user.id.to_s)
    public_send(verb, path, params: body, as: :json)
    response.status
  end

  REQUESTS.each_key do |name|
    it "#{name}: #{EXPECTED[name].zip(%w[signed-out viewer hr_manager admin]).map { |s, who| "#{who} #{s}" }.join(', ')}" do
      other_user = create(:user, email: "other@acme.example", roles: %w[viewer])
      statuses = [ call(name, other_user) ]
      %w[viewer hr_manager admin].each do |role|
        delete "/api/v1/session"
        sign_in_as(role)
        statuses << call(name, other_user)
      end

      expect(statuses).to eq(EXPECTED[name])
    end
  end

  it "combines roles: a user with admin and hr_manager can do both" do
    sign_in_as(:admin, :hr_manager)

    get "/api/v1/employees"
    expect(response).to have_http_status(:ok)
    get "/api/v1/users"
    expect(response).to have_http_status(:ok)
  end

  it "explains a 403 in the standard error shape" do
    sign_in_as(:viewer)
    get "/api/v1/employees"

    expect(response.parsed_body["error"]).to eq("code" => "forbidden", "message" => "Your role does not allow this", "details" => {})
  end

  it "records the signed-in user as the author of a change" do
    sign_in_as(:hr_manager, email: "hr@acme.example")
    patch "/api/v1/employees/#{employee.id}", params: { employee: { job_title: "Staff Engineer" } }, as: :json

    expect(Version.where(item: employee, event: "update").sole.whodunnit).to eq("hr@acme.example")
  end

  it "accepts changes only as JSON, which a form on another site cannot send" do
    sign_in_as(:hr_manager)
    post "/api/v1/employees", params: { employee: { full_name: "Form Post" } } # form-encoded, like an HTML form

    expect(response).to have_http_status(:unsupported_media_type)
    expect(response.parsed_body["error"]["code"]).to eq("json_required")

    post "/graphql", params: { query: "{ dashboard { headcount } }" }
    expect(response).to have_http_status(:unsupported_media_type)
  end

  it "keeps the health check and the app page open" do
    get "/up"
    expect(response).to have_http_status(:ok)
  end
end
