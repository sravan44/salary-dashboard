class ApplicationMailer < ActionMailer::Base
  # MAIL_FROM, else the SMTP account itself (Gmail rewrites any other sender), else a placeholder for local use.
  default from: -> { ENV["MAIL_FROM"].presence || ENV["SMTP_USERNAME"].presence || "no-reply@acme.example" }
  layout "mailer"
end
