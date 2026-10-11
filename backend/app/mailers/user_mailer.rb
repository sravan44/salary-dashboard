# Account emails. They carry a link, never a password: the link is signed, expires, and works once.
# The token sits after "#", so the browser keeps it and it never reaches the server's request logs.
class UserMailer < ApplicationMailer
  def invitation(user)
    @user = user
    @link = link(user.generate_token_for(:password_setup))
    mail to: user.email, subject: "Your ACME Salary Insights account"
  end

  def password_reset(user)
    @user = user
    @link = link(user.password_reset_token)
    mail to: user.email, subject: "Reset your ACME Salary Insights password"
  end

  private

  def link(token) = "#{Rails.configuration.x.app_url}/reset-password#token=#{token}"
end
