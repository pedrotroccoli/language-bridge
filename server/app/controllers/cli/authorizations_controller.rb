# Web side of the `lb login` loopback flow. A signed-in user lands here from the
# CLI's browser hand-off, confirms the machine, and is redirected back to the
# CLI's loopback server with a one-time code. Cookie-authenticated (inherits
# ApplicationController) so it's the logged-in human granting access, not a token.
class Cli::AuthorizationsController < ApplicationController
  def new
    @name = device_name
    @redirect_uri = params[:redirect_uri].to_s
    @state = params[:state].to_s
    @scopes = requested_scopes
    @invalid = !loopback?(@redirect_uri)
    render :new, status: (@invalid ? :unprocessable_entity : :ok)
  end

  def create
    @redirect_uri = params[:redirect_uri].to_s
    @name = device_name
    @state = params[:state].to_s
    @scopes = requested_scopes
    if !loopback?(@redirect_uri)
      @invalid = true
      return render :new, status: :unprocessable_entity
    end

    code = CliAuthCode.issue(user: current_user, name: device_name, scopes: @scopes)
    redirect_to callback_url(@redirect_uri, code: code, state: @state), allow_other_host: true
  end

  private
    def device_name
      params[:name].to_s.presence&.slice(0, 60) || "cli"
    end

    # What the token will actually be granted: the CLI's request, clamped to the
    # signed-in user's role. Shown on the approval page and stored on the code.
    def requested_scopes
      requested = Array(params[:scopes]).presence || PersonalAccessToken::DEFAULT_SCOPES
      PersonalAccessToken.clamp_scopes(current_user, requested)
    end

    # Only ever redirect to a loopback address the CLI itself listens on — never
    # an arbitrary external host (which would leak the code).
    def loopback?(uri)
      parsed = URI.parse(uri)
      parsed.scheme == "http" && [ "127.0.0.1", "localhost", "::1" ].include?(parsed.host)
    rescue URI::InvalidURIError
      false
    end

    def callback_url(uri, code:, state:)
      parsed = URI.parse(uri)
      query = URI.decode_www_form(parsed.query || "")
      query << [ "code", code ]
      query << [ "state", state ] if state.present?
      parsed.query = URI.encode_www_form(query)
      parsed.to_s
    end
end
