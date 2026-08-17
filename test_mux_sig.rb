require 'openssl'
require 'active_support/security_utils'

secret = 'test_secret'
timestamp = Time.now.to_i.to_s
payload = '{"data":{"passthrough":"1","id":"new_asset_id","playback_ids":[{"policy":"signed","id":"new_playback_id"}]},"type":"video.asset.ready"}'
signature = OpenSSL::HMAC.hexdigest('SHA256', secret, "#{timestamp}.#{payload}")

puts "Expected: #{signature}"
expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")
puts "Matches? #{ActiveSupport::SecurityUtils.secure_compare(expected, signature)}"
