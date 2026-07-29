class SignInMailer < ApplicationMailer
  def magic_link
    @token = params[:token]
    @url = sign_in_with_token_url(token: @token.token)
    # Inline (CID) logo; small variant keeps the message light (full logo is multi-MB).
    attachments.inline["logo.png"] = Rails.root.join("app/assets/images/logo-email.png").read
    @logo = attachments["logo.png"].url
    mail to: @token.user.email, subject: "Your Language Bridge sign-in link"
  end
end
