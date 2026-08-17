require "openssl"

class Webhooks::MuxController < ApplicationController
  skip_before_action :verify_authenticity_token

  rescue_from ActionController::BadRequest do
    render json: { error: "Invalid webhook signature" }, status: :bad_request
  end

  before_action :verify_signature!

  def create
    event = JSON.parse(request.raw_post)
    data  = event.fetch("data", {})
    episode = Episode.find_by(id: data["passthrough"].to_s)
    return head :no_content unless episode

    case event["type"]
    when "video.asset.ready"
      playback_id = data
        .fetch("playback_ids", [])
        .find { |p| p["policy"] == MuxVideo.playback_policy }
        &.fetch("id", nil)

      episode.update!(
        mux_asset_id:   data.fetch("id"),
        mux_playback_id: playback_id,
        duration:        data["duration"]&.round,
        video_status:    :ready
      )

      Rails.logger.info "[Mux] Episode #{episode.id} ready — playback_id=#{playback_id}"

    when "video.asset.errored"
      episode.update!(
        mux_asset_id: data.fetch("id"),
        video_status: :errored
      )
      Rails.logger.warn "[Mux] Episode #{episode.id} errored"

    when "video.upload.asset_created"
      asset_id = data["asset_id"] || data.dig("new_asset_settings", "passthrough")
      episode.update!(video_status: :processing) if asset_id
      Rails.logger.info "[Mux] Episode #{episode.id} processing"

    end

    head :no_content
  rescue JSON::ParserError
    render json: { error: "Invalid webhook payload" }, status: :bad_request
  rescue ActiveRecord::RecordNotFound, KeyError => e
    Rails.logger.error "[Mux] Webhook error: #{e.message}"
    head :no_content 
  end

  private

  def verify_signature!
    secret = ENV.fetch("MUX_WEBHOOK_SECRET") { raise ActionController::BadRequest }

    raw_header = request.headers["Mux-Signature"].to_s
    parts      = raw_header.split(",").each_with_object({}) do |part, hash|
      k, v = part.split("=", 2)
      hash[k] = v if k && v
    end

    timestamp = parts["t"].to_s
    signature = parts["v1"].to_s

    raise ActionController::BadRequest if timestamp.blank? || signature.blank?

    age = (Time.current.to_i - timestamp.to_i).abs
    raise ActionController::BadRequest if age > 300

    expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{request.raw_post}")
    raise ActionController::BadRequest unless ActiveSupport::SecurityUtils.secure_compare(expected, signature)
  end
end
