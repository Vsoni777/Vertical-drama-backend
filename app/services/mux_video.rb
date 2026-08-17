require "net/http"

class MuxVideo
  class Error < StandardError; end

  API_BASE_URL = "https://api.mux.com/video/v1".freeze

  def self.create_direct_upload!(episode_id:, cors_origin:, new_asset_settings: {})
    response = post(
      "/uploads",
      cors_origin: cors_origin.presence || default_cors_origin,
      new_asset_settings: {
        playback_policies: [ playback_policy ],
        passthrough: episode_id.to_s
      }.merge(new_asset_settings)
    )

    response.fetch("data")
  end

  def self.post(path, body)
    token_id = ENV.fetch("MUX_TOKEN_ID")
    token_secret = ENV.fetch("MUX_TOKEN_SECRET")
    uri = URI("#{API_BASE_URL}#{path}")
    request = Net::HTTP::Post.new(uri)
    request.basic_auth(token_id, token_secret)
    request["Content-Type"] = "application/json"
    request.body = body.to_json

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
    parsed = JSON.parse(response.body)
    return parsed if response.is_a?(Net::HTTPSuccess)

    error_msg = parsed.dig("error", "message") || parsed.dig("error", "messages")&.join(", ") || "Mux returned HTTP #{response.code}"
    raise Error, error_msg
  rescue KeyError
    raise Error, "MUX_TOKEN_ID and MUX_TOKEN_SECRET must be configured"
  rescue JSON::ParserError
    raise Error, "Mux returned an invalid response (HTTP #{response&.code})"
  end

  def self.playback_policy
    ENV.fetch("MUX_PLAYBACK_POLICY", "signed")
  end

  def self.default_cors_origin
    ENV.fetch("FRONTEND_URL", "https://vertical-drama-five.vercel.app")
  end
end
