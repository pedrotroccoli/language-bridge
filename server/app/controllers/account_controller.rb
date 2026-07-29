# The signed-in user's own account: profile + active sessions. Auth is
# passwordless (magic link), so there's no password to manage here.
class AccountController < ApplicationController
  def show
    @sessions = current_user.sessions.order(created_at: :desc)
  end

  def update
    if current_user.update(account_params)
      redirect_to account_path, notice: "Profile updated."
    else
      @sessions = current_user.sessions.order(created_at: :desc)
      render :show, status: :unprocessable_entity
    end
  end

  private
    def account_params
      params.expect(user: %i[ name avatar ])
    end
end
