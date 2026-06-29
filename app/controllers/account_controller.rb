# The signed-in user's own account: profile + active sessions. Auth is
# passwordless (magic link), so there's no password to manage here.
class AccountController < ApplicationController
  def show
    @sessions = current_user.sessions.order(created_at: :desc)
  end
end
