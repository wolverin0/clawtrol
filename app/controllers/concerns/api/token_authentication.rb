module Api
  module TokenAuthentication
    extend ActiveSupport::Concern

    included do
      before_action :authenticate_api_token
      attr_reader :current_user
    end

    private

    def authenticate_api_token
      token = extract_token_from_header
      @current_user = ApiToken.authenticate(token)

      unless @current_user
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end

    def extract_token_from_header
      auth_header = request.headers["Authorization"]
      return nil unless auth_header

      # Expected format: "Bearer <token>"
      match = auth_header.match(/\ABearer\s+(.+)\z/i)
      match&.[](1)
    end
  end
end
