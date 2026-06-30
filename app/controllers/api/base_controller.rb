module Api
  # Base for all JSON API endpoints. Authenticates a per-project bearer token
  # (see ApiToken) resolved from the `:project_slug` URL segment. Unlike the web
  # controllers it does not use cookie sessions or CSRF.
  class BaseController < ActionController::API
    before_action :authenticate_api_token!

    private
      def authenticate_api_token!
        @project = Project.find_by(slug: params[:project_slug])
        return render_error(:not_found, "Project not found") if @project.nil?

        @api_token = authenticate_token
        return render_error(:unauthorized, "Invalid or missing API token") if @api_token.nil?

        Current.api_token = @api_token
      end

      # A personal access token (lb_pat_…) authenticates as its user across the
      # projects they can access; otherwise fall back to a per-project ApiToken.
      def authenticate_token
        if (pat = PersonalAccessToken.authenticate(bearer_token))
          return pat if pat.user.accessible_projects.exists?(id: @project.id)
          return nil
        end

        ApiToken.authenticate(bearer_token, project: @project)&.tap(&:touch_last_used!)
      end

      def bearer_token
        header = request.authorization
        return unless header&.start_with?("Bearer ")

        header.split(" ", 2).last
      end

      # An `admin` token satisfies every scope.
      def require_scope!(*scopes)
        allowed = scopes.map(&:to_s)
        return if allowed.include?(@api_token.scope) || @api_token.scope == "admin"

        render_error(:forbidden, "Token lacks the required scope")
      end

      def render_error(status, message)
        render json: { error: message }, status: status
      end
  end
end
