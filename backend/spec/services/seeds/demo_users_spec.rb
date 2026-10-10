require "rails_helper"

RSpec.describe Seeds::DemoUsers do
  it "creates one sign-in per role with the documented local password" do
    created = described_class.call

    expect(created).to eq(%w[admin@acme.example hr@acme.example viewer@acme.example])
    expect(User.order(:email).pluck(:email, :roles)).to eq([
      [ "admin@acme.example", %w[viewer hr_manager admin] ],
      [ "hr@acme.example", %w[hr_manager] ],
      [ "viewer@acme.example", %w[viewer] ]
    ])
    expect(User.all).to all(satisfy { |user| user.authenticate("local-demo-password") })
  end

  it "uses DEMO_USER_PASSWORD instead when it is given" do
    described_class.call(password: "another demo password")

    expect(User.find_by!(email: "hr@acme.example").authenticate("another demo password")).to be_truthy
  end

  it "never changes users that already exist (e.g. a changed password or roles)" do
    create(:user, email: "admin@acme.example", roles: %w[admin], password: "changed by the admin")

    expect(described_class.call).to eq(%w[hr@acme.example viewer@acme.example])
    expect(User.find_by!(email: "admin@acme.example")).to have_attributes(roles: %w[admin])
    expect(User.find_by!(email: "admin@acme.example").authenticate("changed by the admin")).to be_truthy
  end

  it "creates nothing in production without an explicit DEMO_USER_PASSWORD, so the documented password never works there" do
    allow(Rails.env).to receive(:production?).and_return(true)

    expect(described_class.call(password: nil)).to eq([])
    expect(User.count).to eq(0)
  end

  it "creates them in production only when DEMO_USER_PASSWORD is set on purpose (e.g. a demo deployment)" do
    allow(Rails.env).to receive(:production?).and_return(true)

    expect(described_class.call(password: "a demo-only password").size).to eq(3)
  end
end
