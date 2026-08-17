class Api::BaseController < ApplicationController
  before_action :authenticate_user!

  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "Resource not found" }, status: :not_found
  end

  rescue_from MuxPlaybackToken::ConfigurationError do |error|
    Rails.logger.error(error.message)
    render json: { error: "Video playback is temporarily unavailable" }, status: :service_unavailable
  end

  private

  def require_admin!
    return if current_user.admin?

    render json: { error: "Administrator access is required" }, status: :forbidden
  end
end
