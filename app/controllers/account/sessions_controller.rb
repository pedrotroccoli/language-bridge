# The signed-in user's sessions. Destroying signs out everywhere but here.
class Account::SessionsController < ApplicationController
  def destroy
    current_user.sessions.where.not(id: Current.session.id).destroy_all
    redirect_to account_path, notice: "Signed out of all other sessions."
  end
end
