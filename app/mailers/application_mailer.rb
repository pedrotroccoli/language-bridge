class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "Language Bridge <onboarding@resend.dev>")
  layout "mailer"
end
