class SessionsController < ApplicationController
  allow_unauthenticated only: %i[ new create show ]

  def new
  end

  def create
    user = User.find_or_initialize_by(email: params[:email].to_s.strip.downcase)

    if user.new_record?
      if User.none?
        # Bootstrap: first sign-in becomes admin.
        user.role = "admin"
        user.save!
      else
        redirect_to sign_in_path, alert: "No account for that email. Ask an admin to invite you." and return
      end
    end

    token = user.sign_in_tokens.create!
    SignInMailer.with(token: token).magic_link.deliver_later

    redirect_to sign_in_path, notice: "Check your email for a sign-in link."
  end

  def show
    token = SignInToken.fresh.find_by(token: params[:token])

    if token
      sign_in_as(token.user)
      token.destroy!
      redirect_to root_path, notice: "Signed in."
    else
      redirect_to sign_in_path, alert: "Link expired or invalid."
    end
  end

  def destroy
    sign_out
    redirect_to sign_in_path, notice: "Signed out."
  end
end
