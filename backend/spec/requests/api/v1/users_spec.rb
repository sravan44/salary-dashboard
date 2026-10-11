require "rails_helper"

RSpec.describe "User management API (admin)" do
  include ActiveJob::TestHelper

  let!(:admin) { sign_in_as(:admin, email: "admin@acme.example") }

  it "lists users with their roles, by email" do
    create(:user, email: "b@acme.example", roles: %w[viewer])
    get "/api/v1/users"

    expect(response.parsed_body["data"].map { |u| [ u["email"], u["roles"] ] })
      .to eq([ [ "admin@acme.example", %w[admin] ], [ "b@acme.example", %w[viewer] ] ])
    expect(response.parsed_body["data"].first.keys).to contain_exactly("id", "email", "roles", "password_set", "created_at")
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

    it "sends no email when the admin sets the first password" do
      expect do
        post "/api/v1/users", params: { user: { email: "set@acme.example", roles: %w[viewer], password: "a long first password" } }, as: :json
      end.not_to have_enqueued_mail

      expect(response.parsed_body["data"]["password_set"]).to be(true)
    end

    it "without a password, sends nothing yet and the account can't be used until a password is set" do
      expect do
        post "/api/v1/users", params: { user: { email: "invited@acme.example", roles: %w[viewer] } }, as: :json
      end.not_to have_enqueued_mail

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["data"]["password_set"]).to be(false)
      invited = User.find_by!(email: "invited@acme.example")
      expect(invited.password_changed_at).to be_nil
      expect(invited.password_digest).to be_present # a random, never-shown placeholder
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

  describe "setting someone's password" do
    let!(:person) { create(:user, email: "person@acme.example", roles: %w[viewer], password_changed_at: nil) }

    it "sets it, signs the person out everywhere, and records who did it" do
      Session.start(person)
      patch "/api/v1/users/#{person.id}/password", params: { password: "set by the admin!", password_confirmation: "set by the admin!" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]["password_set"]).to be(true)
      expect(person.reload.authenticate("set by the admin!")).to eq(person)
      expect(person.sessions).to be_empty
      expect(Version.where(item: person, event: "update").last.whodunnit).to eq("admin@acme.example")
    end

    it "returns field errors for a short password" do
      patch "/api/v1/users/#{person.id}/password", params: { password: "short" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]["details"]).to eq("password" => [ "is too short (minimum is 12 characters)" ])
    end

    it "answers 404 for an unknown user" do
      patch "/api/v1/users/0/password", params: { password: "set by the admin!" }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "sending password links" do
    let!(:invited) { create(:user, email: "invited@acme.example", password_changed_at: nil) }
    let!(:active) { create(:user, email: "active@acme.example") }

    def send_links(ids) = post("/api/v1/users/password_links", params: { user_ids: ids }, as: :json)

    it "emails each chosen user the right link: set-password if they have none yet, otherwise a reset link" do
      expect { send_links([ invited.id, active.id ]) }
        .to have_enqueued_mail(UserMailer, :invitation).with(invited)
        .and have_enqueued_mail(UserMailer, :password_reset).with(active)

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body["data"]).to eq("sent" => 2)
    end

    it "sends each user one email even when chosen twice" do
      expect { send_links([ active.id, active.id ]) }.to have_enqueued_mail(UserMailer, :password_reset).once
    end

    it "sends nothing when any chosen user does not exist" do
      expect { send_links([ active.id, 0 ]) }.not_to have_enqueued_mail

      expect(response).to have_http_status(:not_found)
    end

    it "needs at least one user, and at most 50" do
      send_links([])
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]["details"]).to eq("user_ids" => [ "choose between 1 and 50 users" ])

      send_links((1..51).to_a) # 51 different users
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
