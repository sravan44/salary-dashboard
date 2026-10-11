require "rails_helper"

# Password links: a set-password link for new users (24 h) and a reset link (2 h). Both are signed,
# expire, and stop working as soon as the password changes, so each link works once.
RSpec.describe User, "password links" do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }

  it "finds the user by a reset token for 2 hours, then not" do
    token = user.password_reset_token

    travel 119.minutes do
      expect(User.find_by_password_reset_token(token)).to eq(user)
    end
    travel 121.minutes do
      expect(User.find_by_password_reset_token(token)).to be_nil
    end
  end

  it "finds the user by a set-password token for 24 hours, then not" do
    token = user.generate_token_for(:password_setup)

    travel 23.hours do
      expect(User.find_by_token_for(:password_setup, token)).to eq(user)
    end
    travel 25.hours do
      expect(User.find_by_token_for(:password_setup, token)).to be_nil
    end
  end

  it "stops honouring both kinds of link once the password changes" do
    reset = user.password_reset_token
    setup = user.generate_token_for(:password_setup)
    user.update!(password: "a brand new password")

    expect(User.find_by_password_reset_token(reset)).to be_nil
    expect(User.find_by_token_for(:password_setup, setup)).to be_nil
  end

  it "does not accept one kind of link as the other" do
    expect(User.find_by_token_for(:password_setup, user.password_reset_token)).to be_nil
    expect(User.find_by_password_reset_token(user.generate_token_for(:password_setup))).to be_nil
  end

  it "knows whether the user has chosen a password yet" do
    expect(build(:user, password_changed_at: nil).password_set?).to be(false)
    expect(build(:user, password_changed_at: Time.current).password_set?).to be(true)
  end
end
