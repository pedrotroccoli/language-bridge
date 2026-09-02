module Api
  module V1
    module Cli
      # Exchange step of the `lb login` loopback flow: the CLI posts the one-time
      # code it received on its loopback callback and gets a freshly-minted
      # personal access token. Unauthenticated — the code is the credential.
      #
      #   POST /api/v1/cli/token   { code }  ->  { token, user: { email, name } }
      class TokensController < ActionController::API
        def create
          redemption = CliAuthCode.redeem(params[:code])
          return render json: { error: "Invalid or expired code" }, status: :unauthorized if redemption.nil?

          render json: {
            token: redemption.token,
            user: { email: redemption.user.email, name: redemption.user.name }
          }
        rescue PersonalAccessToken::LimitReached => e
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end
    end
  end
end
