# The signed-in user's personal access token (lb_pat_…). Create regenerates,
# replacing any existing token; the raw value is flashed once for copying.
class Account::PersonalAccessTokensController < ApplicationController
  def create
    raw = PersonalAccessToken.regenerate_for(current_user)
    redirect_to account_path, flash: { pat_created: raw }
  end

  def destroy
    current_user.personal_access_token&.destroy!
    redirect_to account_path, notice: "Personal access token revoked."
  end
end
