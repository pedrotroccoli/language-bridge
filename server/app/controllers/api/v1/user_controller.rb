module Api
  module V1
    # Identity endpoint for `lb whoami`: resolves the personal access token to its
    # user and the projects it can reach. PAT-authenticated and project-less, so
    # it doesn't share Api::BaseController's per-project token lookup.
    #
    #   GET /api/v1/user  ->  { user: { email, name }, projects: ["main-app", …] }
    class UserController < ActionController::API
      before_action :authenticate_personal_access_token!

      def show
        render json: {
          user: { email: @pat.user.email, name: @pat.user.name },
          projects: @pat.user.accessible_projects.order(:slug).pluck(:slug)
        }
      end

      private
        def authenticate_personal_access_token!
          header = request.authorization
          raw = header&.start_with?("Bearer ") ? header.split(" ", 2).last : nil
          @pat = PersonalAccessToken.authenticate(raw)
          render json: { error: "Invalid or missing token" }, status: :unauthorized if @pat.nil?
        end
    end
  end
end
