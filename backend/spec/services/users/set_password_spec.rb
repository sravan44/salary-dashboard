require "rails_helper"

RSpec.describe Users::SetPassword do
  let(:user) { create(:user, email: "person@acme.example", password_changed_at: nil) }

  it "sets the password, stamps when, and audits who did it without the password" do
    Current.actor = "admin@acme.example"
    result = described_class.call(user, password: "a brand new password", password_confirmation: "a brand new password")

    expect(result).to be_success
    expect(user.reload.authenticate("a brand new password")).to eq(user)
    expect(user.password_changed_at).to be_within(5.seconds).of(Time.current)
    version = Version.where(item: user, event: "update").sole
    expect(version.whodunnit).to eq("admin@acme.example")
    expect(version.object_changes.keys).to eq([ "password_changed_at" ])
  ensure
    Current.reset
  end

  it "ends every session of the user except the one given" do
    keep, = Session.start(user)
    Session.start(user)
    Session.start(user)

    described_class.call(user, password: "a brand new password", keep_session: keep)

    expect(user.sessions.reload).to contain_exactly(keep)
  end

  it "ends all sessions when none is kept" do
    Session.start(user)

    described_class.call(user, password: "a brand new password")

    expect(user.sessions.reload).to be_empty
  end

  it "refuses a short or unconfirmed password and changes nothing" do
    session, = Session.start(user)
    digest = user.password_digest

    short = described_class.call(user, password: "short")
    mismatch = described_class.call(user, password: "a brand new password", password_confirmation: "something else")

    expect(short.errors).to eq("password" => [ "is too short (minimum is 12 characters)" ])
    expect(mismatch.errors).to eq("password_confirmation" => [ "doesn't match Password" ])
    expect(user.reload).to have_attributes(password_digest: digest, password_changed_at: nil)
    expect(user.sessions).to contain_exactly(session)
  end

  it "refuses a blank password" do
    expect(described_class.call(user, password: "").errors).to eq("password" => [ "can't be blank" ])
  end
end
