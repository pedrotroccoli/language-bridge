class SignInMailer < ApplicationMailer
  def magic_link
    @token = params[:token]
    @url = sign_in_url(token: @token.token)
    mail to: @token.user.email, subject: "Your Language Bridge sign-in link"
  end
end
