require "rails_helper"

RSpec.describe User do
  it "stores the email in lower case and only a password digest" do
    user = create(:user, email: "  Asha.Rao@ACME.example ", password: "correct horse battery")

    expect(user.email).to eq("asha.rao@acme.example")
    expect(user.password_digest).to start_with("$2a$")
    expect(user.authenticate("correct horse battery")).to eq(user)
  end

  it "requires a password of 12 to 72 characters" do
    expect(build(:user, password: "a" * 11)).not_to be_valid
    expect(build(:user, password: "a" * 12)).to be_valid
    expect(build(:user, password: "a" * 73)).not_to be_valid
  end

  it "requires at least one role, and only known roles" do
    expect(build(:user, roles: []).tap(&:validate).errors[:roles]).to eq([ "must include at least one role" ])
    expect(build(:user, roles: %w[viewer superuser]).tap(&:validate).errors[:roles]).to eq([ "contains an unknown role: superuser" ])
  end

  it "keeps roles unique and in a stable order" do
    expect(create(:user, roles: %w[admin viewer admin]).roles).to eq(%w[viewer admin])
  end

  it "is backed by a database check, even if validations are skipped" do
    user = build(:user, roles: [ "superuser" ])

    expect { user.save(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /users_roles_valid/)
  end

  it "rejects a duplicate email" do
    create(:user, email: "a@acme.example")

    expect(build(:user, email: "A@acme.example")).not_to be_valid
  end

  describe "permissions (roles combine)" do
    it "lets everyone signed in see the dashboard, HR manage employees and Admin manage users" do
      viewer = build(:user, roles: %w[viewer])
      hr = build(:user, roles: %w[hr_manager])
      admin_and_hr = build(:user, roles: %w[admin hr_manager])

      expect([ viewer, hr, admin_and_hr ].map { |u| u.can?(:view_dashboard) }).to eq([ true, true, true ])
      expect([ viewer, hr, admin_and_hr ].map { |u| u.can?(:manage_employees) }).to eq([ false, true, true ])
      expect([ viewer, hr, admin_and_hr ].map { |u| u.can?(:manage_users) }).to eq([ false, false, true ])
    end
  end

  it "records role changes in the audit log, but never the password" do
    Current.actor = "admin@acme.example"
    user = create(:user, roles: %w[viewer])
    user.update!(roles: %w[viewer hr_manager], password: "another long password")

    changes = Version.where(item: user).order(:id).map(&:object_changes)
    expect(changes.last).to eq("roles" => [ %w[viewer], %w[viewer hr_manager] ])
    expect(changes.flat_map(&:keys)).not_to include("password_digest")
  end
end
