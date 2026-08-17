require 'rails_helper'

RSpec.describe Api::V1::CoinsController, type: :controller do
  let(:user) { create(:user, coin_balance: 100) }

  describe 'POST #purchase' do
    before do
      sign_in user
      ENV['STRIPE_SECRET_KEY'] = 'test_key'
    end
    after { ENV['STRIPE_SECRET_KEY'] = nil }

    it 'creates a stripe checkout session' do
      session_double = double(url: 'http://checkout.url', id: 'cs_123')
      allow(Stripe::Checkout::Session).to receive(:create).and_return(session_double)
      
      post :purchase, params: { pack: 'small' }
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['data']['checkout_url']).to eq('http://checkout.url')
    end

    it 'returns error for invalid pack' do
      post :purchase, params: { pack: 'invalid' }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
