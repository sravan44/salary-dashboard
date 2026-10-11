require "rails_helper"

RSpec.describe UserMailer do
  let(:user) { create(:user, email: "new.person@acme.example", password: "the first password!") }

  def link_token(mail)
    mail.text_part.body.decoded[%r{http://localhost:3000/reset-password#token=(\S+)}, 1]
  end

  describe "invitation" do
    let(:mail) { described_class.invitation(user) }

    it "invites the user with a set-password link and no password, in text and HTML" do
      expect(mail.to).to eq([ "new.person@acme.example" ])
      expect(mail.from).to eq([ "no-reply@acme.example" ])
      expect(mail.subject).to eq("Your ACME Salary Insights account")
      [ mail.text_part, mail.html_part ].each do |part|
        expect(part.body.decoded).to include("new.person@acme.example", "http://localhost:3000/reset-password#token=", "24 hours")
        expect(part.body.decoded).not_to include("the first password!")
      end
      expect(User.find_by_token_for(:password_setup, link_token(mail))).to eq(user)
    end
  end

  describe "password_reset" do
    let(:mail) { described_class.password_reset(user) }

    it "sends a reset link that works for this user, and says it expires" do
      expect(mail.to).to eq([ "new.person@acme.example" ])
      expect(mail.subject).to eq("Reset your ACME Salary Insights password")
      expect(mail.text_part.body.decoded).to include("2 hours", "If you didn't ask")
      expect(User.find_by_password_reset_token(link_token(mail))).to eq(user)
    end
  end
end
