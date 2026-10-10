require "rails_helper"

RSpec.describe "User management API (admin)" do
  let!(:admin) { sign_in_as(:admin, email: "admin@acme.example") }

  it "lists users with their roles, by email" do
    create(:user, email: "b@acme.example", roles: %w[viewer])
    get "/api/v1/users"

    expect(response.parsed_body["data"].map { |u| [ u["email"], u["roles"] ] })
      .to eq([ [ "admin@acme.example", %w[admin] ], [ "b@acme.example", %w[viewer] ] ])
    expect(response.parsed_body["data"].first.keys).to contain_exactly("id", "email", "roles", "created_at")
  end

  describe "creating a user" do
    it "creates the user with roles and a first password, and they can sign in" do
      post "/api/v1/users", params: { user: { email: "New.Person@acme.example", roles: %w[viewer hr_manager], password: "a long first password" } }, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["data"]).to include("email" => "new.person@acme.example", "roles" => %w[viewer hr_manager])
      expect(response.parsed_body["data"]).not_to have_key("password_digest")

      delete "/api/v1/session"
      post "/api/v1/session", params: { email: "new.person@acme.example", password: "a long first password" }, as: :json
      expect(response).to have_http_status(:created)
    end

    it "returns field errors for a short password, no roles or a taken email" do
      post "/api/v1/users", params: { user: { email: "admin@acme.example", roles: [], password: "short" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]["details"].keys).to contain_exactly("email", "roles", "password")
    end
  end

  describe "changing roles" do
    let!(:person) { create(:user, email: "person@acme.example", roles: %w[viewer]) }

    def change(user, roles)
      patch "/api/v1/users/#{user.id}", params: { user: { roles: } }, as: :json
    end

    it "replaces the user's roles, records who did it, and leaves the password alone" do
      digest = person.password_digest
      change(person, %w[viewer hr_manager])

      expect(response).to have_http_status(:ok)
      expect(person.reload).to have_attributes(roles: %w[viewer hr_manager], password_digest: digest)
      expect(Version.where(item: person, event: "update").sole)
        .to have_attributes(whodunnit: "admin@acme.example", object_changes: { "roles" => [ %w[viewer], %w[viewer hr_manager] ] })
    end

    it "requires at least one role" do
      change(person, [])

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]["details"]).to eq("roles" => [ "must include at least one role" ])
    end

    it "does not let an admin remove their own admin role" do
      create(:user, email: "second.admin@acme.example", roles: %w[admin])
      change(admin, %w[viewer])

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]["details"]).to eq("roles" => [ "you cannot remove your own Admin role" ])
      expect(admin.reload.roles).to eq(%w[admin])
    end

    it "never removes the admin role from the last admin" do
      other_admin = create(:user, email: "z.admin@acme.example", roles: %w[admin])
      change(other_admin, %w[viewer])
      expect(response).to have_http_status(:ok)

      # Now admin@ is the only admin; even with another admin's account the rule holds.
      expect(Users::UpdateRoles.call(admin, roles: %w[viewer], by: other_admin.reload).errors)
        .to eq("roles" => [ "at least one Admin must remain" ])
    end

    it "only changes roles (email and password are not editable here)" do
      patch "/api/v1/users/#{person.id}", params: { user: { roles: %w[viewer], email: "x@acme.example", password: "another long password" } }, as: :json

      expect(person.reload.email).to eq("person@acme.example")
      expect(person.authenticate("correct horse battery")).to be_truthy
    end

    it "returns 404 for an unknown user" do
      change(User.new(id: 0), %w[viewer])

      expect(response).to have_http_status(:not_found)
    end
  end
end
