# Web side of the `lb login` loopback flow. A signed-in user lands here from the
# CLI's browser hand-off, confirms the machine, and is redirected back to the
# CLI's loopback server with a one-time code. Cookie-authenticated (inherits
# ApplicationController) so it's the logged-in human granting access, not a token.
class Cli::AuthorizationsController < ApplicationController
  include Cli::Loopback

  before_action :set_grant

  def new
    @invalid = !valid_grant?
    render :new, status: (@invalid ? :unprocessable_entity : :ok)
  end

  def create
    if !valid_grant?
      @invalid = true
      return render :new, status: :unprocessable_entity
    end

    code = CliAuthCode.issue(user: current_user, name: @name, scopes: @scopes)
    redirect_to callback_url(@redirect_uri, code: code, state: @state), allow_other_host: true
  end

  private
    # Both actions render the same approval context (create re-renders it on an
    # invalid redirect), so it's assembled in one place.
    def set_grant
      @name = params[:name].to_s.presence&.slice(0, 60) || "cli"
      @redirect_uri = params[:redirect_uri].to_s
      @state = params[:state].to_s
      @scopes = requested_scopes
      @verification_code = verification_code(@state)
    end

    # Human-checkable fingerprint of the request, derived from the CLI's
    # `state` exactly as the CLI derives it (see login.ts). The terminal prints
    # the same code, so the user can confirm the approval page belongs to their
    # own `lb login` run before granting anything.
    def verification_code(state)
      return if state.blank?

      Digest::SHA256.hexdigest(state).first(8).upcase.insert(4, "-")
    end

    # What the token will actually be granted: the CLI's request, clamped to
    # the signed-in user's role — minus admin, which this flow never mints no
    # matter what the URL asks for. The approval page promises "it will never
    # be able to administer projects", so that must hold even for a crafted
    # authorize link an admin user is tricked into approving.
    def requested_scopes
      requested = Array(params[:scopes]).presence || PersonalAccessToken::DEFAULT_SCOPES
      PersonalAccessToken.clamp_scopes(current_user, requested) - [ "admin" ]
    end

    # The CLI always sends `state`, and the verification code is derived from
    # it — a request without one has no code for the user to check against
    # their terminal, so it fails closed rather than rendering an approvable
    # page with the anti-phishing affordance silently missing.
    def valid_grant?
      loopback?(@redirect_uri) && @state.present?
    end
end
