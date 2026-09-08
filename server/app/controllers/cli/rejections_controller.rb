# Reject half of the `lb login` approval. Nothing to revoke — the one-time
# code is only minted on approval — so this bounces the browser back to the
# CLI's loopback with error=access_denied, letting the terminal fail
# immediately instead of waiting out its timeout. Without a loopback to
# notify, it falls back to a standalone confirmation page.
class Cli::RejectionsController < ApplicationController
  def show
    callback = Cli::Callback.new(params[:redirect_uri])
    if callback.loopback?
      redirect_to callback.url(error: "access_denied", state: params[:state].to_s), allow_other_host: true
    end
  end
end
