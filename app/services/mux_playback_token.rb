require "base64"
require "openssl"

class MuxPlaybackToken
  class ConfigurationError < StandardError; end

  TOKEN_TTL_SECONDS = 600 

  def self.generate(playback_id)
    key_id     = fetch_key_id
    private_key = fetch_private_key

    now     = Time.current.to_i
    header  = { alg: "RS256", typ: "JWT", kid: key_id }
    payload = { aud: "v", sub: playback_id, iat: now, exp: now + TOKEN_TTL_SECONDS }

    signing_input = [ header, payload ]
      .map { |part| base64url(part.to_json) }
      .join(".")

    signature = private_key.sign(OpenSSL::Digest.new("SHA256"), signing_input)
    "#{signing_input}.#{base64url(signature)}"
  rescue ConfigurationError
    raise
  rescue OpenSSL::PKey::PKeyError => e
    raise ConfigurationError, "Invalid Mux signing key: #{e.message}"
  rescue StandardError => e
    raise ConfigurationError, "Mux token generation failed: #{e.message}"
  end

  private_class_method def self.fetch_key_id
    id = ENV["MUX_SIGNING_KEY"].presence ||
         Rails.application.credentials.dig(:mux, :signing_key_id).presence
    raise ConfigurationError, "MUX_SIGNING_KEY is not configured" if id.blank?

    id
  end

  private_class_method def self.fetch_private_key
    raw = ENV["MUX_PRIVATE_KEY"].presence ||
          Rails.application.credentials.dig(:mux, :signing_key_private).presence
    raise ConfigurationError, "MUX_PRIVATE_KEY is not configured" if raw.blank?

    pem = if raw.include?("-----BEGIN")
      raw                         
    else
      Base64.decode64(raw)
    end
    pem = pem.gsub("\\n", "\n")

    OpenSSL::PKey.read(pem)
  end

  private_class_method def self.base64url(data)
    Base64.urlsafe_encode64(data, padding: false)
  end
end
