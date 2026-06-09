# Bearer-token authentication for the JSON API. Clients send
# `Authorization: Bearer <token>`; unknown/missing tokens get 401.
module ApiTokenAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_api_token!
  end

  private
    def authenticate_api_token!
      token = request.authorization.to_s.remove(/\ABearer\s+/i)
      @current_api_token = ApiToken.authenticate(token)
      render_unauthorized unless @current_api_token
    end

    def current_user
      @current_api_token&.user
    end

    def render_unauthorized
      response.headers["WWW-Authenticate"] = %(Bearer realm="ghrian")
      render json: { error: "invalid or missing API token" }, status: :unauthorized
    end
end
