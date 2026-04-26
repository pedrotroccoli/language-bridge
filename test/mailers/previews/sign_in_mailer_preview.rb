# Preview all emails at http://localhost:3000/rails/mailers/sign_in_mailer
class SignInMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/sign_in_mailer/magic_link
  def magic_link
    SignInMailer.magic_link
  end
end
