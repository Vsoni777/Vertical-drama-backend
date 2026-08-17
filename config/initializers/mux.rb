
MuxRuby.configure do |config|
  config.username = ENV.fetch("MUX_TOKEN_ID")
  config.password = ENV.fetch("MUX_TOKEN_SECRET")
end