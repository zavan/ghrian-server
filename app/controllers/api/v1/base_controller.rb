module Api
  module V1
    # Base for all token-authenticated JSON endpoints. No session/CSRF; auth is via
    # a bearer token (see ApiTokenAuthentication).
    class BaseController < ActionController::API
      include ApiTokenAuthentication

      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "not found" }, status: :not_found
      end
    end
  end
end
