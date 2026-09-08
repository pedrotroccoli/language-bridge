# Reject half of the `lb login` approval. Nothing to revoke — the one-time
# code is only minted on approval — so this bounces the browser back to the
# CLI's loopback with error=access_denied, letting the terminal fail
# immediately instead of waiting out its timeout. Without a loopback to
# notify, it falls back to a standalone confirmation page.
class Cli::RejectionsController < ApplicationController
  include Cli::Loopback

  def show
    redirect_uri = params[:redirect_uri].to_s
    if loopback?(redirect_uri)
      redirect_to callback_url(redirect_uri, error: "access_denied", state: params[:state].to_s), allow_other_host: true
    end
  end
end
