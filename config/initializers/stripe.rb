require 'stripe'

api_key = ENV['STRIPE_SECRET_KEY'] || ENV['STRIPE_API_KEY']
Stripe.api_key = api_key if api_key && !api_key.empty?
