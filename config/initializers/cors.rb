Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'https://vertical-drama-five.vercel.app'

    resource '*',
      headers: :any,
      methods: %i[get post put patch delete options head],
      credentials: false
  end
end