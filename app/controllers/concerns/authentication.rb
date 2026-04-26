module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate
    helper_method :signed_in?, :current_user
  end

  class_methods do
    def allow_unauthenticated(**options)
      skip_before_action :authenticate, **options
    end
  end

  private
    def authenticate
      Current.session = find_session
      Current.user_agent = request.user_agent
      Current.ip_address = request.remote_ip
      redirect_to sign_in_path unless Current.session
    end

    def find_session
      token = cookies.signed[:session_token]
      return unless token
      Session.find_by(token: token)
    end

    def sign_in_as(user)
      session = user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip)
      cookies.signed.permanent[:session_token] = { value: session.token, httponly: true, same_site: :lax }
      Current.session = session
    end

    def sign_out
      Current.session&.destroy
      cookies.delete(:session_token)
      Current.session = nil
    end

    def signed_in?
      Current.session.present?
    end

    def current_user
      Current.user
    end

    def require_admin
      redirect_to root_path, alert: "Admins only." unless current_user&.admin?
    end
end
