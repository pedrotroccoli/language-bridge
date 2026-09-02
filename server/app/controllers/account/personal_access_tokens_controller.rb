# The signed-in user's personal access tokens (lb_pat_…). Each is named (one per
# machine via `lb login`), capped by Setting#cli_token_limit. The raw value is
# flashed once for copying; only the digest is stored.
class Account::PersonalAccessTokensController < ApplicationController
  def create
    raw = PersonalAccessToken.issue(user: current_user, name: params[:name], scopes: Array(params[:scopes]))
    redirect_to account_path, flash: { pat_created: raw }
  rescue PersonalAccessToken::LimitReached => e
    redirect_to account_path, alert: e.message
  rescue ActiveRecord::RecordInvalid
    redirect_to account_path, alert: "Pick at least one capability for the token."
  end

  def destroy
    current_user.personal_access_tokens.find(params[:id]).destroy!
    redirect_to account_path, notice: "Personal access token revoked."
  end
end
