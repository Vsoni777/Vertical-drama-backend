require 'rails_helper'

RSpec.describe Api::V1::SubscriptionsController, type: :controller do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'GET #show' do
    it 'returns the current active subscription' do
      create(:subscription, user: user, status: :active)
      get :show
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['data']['status']).to eq('active')
    end
  end

  describe 'POST #create' do
    before { ENV['STRIPE_SECRET_KEY'] = 'test_key' }
    after { ENV['STRIPE_SECRET_KEY'] = nil }

    it 'creates a subscription' do
      svc_double = instance_double(StripeSubscriptionService)
      stripe_sub_double = double(id: 'sub_123', current_period_start: Time.current.to_i, current_period_end: 1.month.from_now.to_i)
      
      allow(StripeSubscriptionService).to receive(:new).with(user).and_return(svc_double)
      allow(svc_double).to receive(:create_subscription).with('monthly').and_return(stripe_sub_double)
      
      post :create, params: { plan: 'monthly' }
      
      expect(response).to have_http_status(:created)
      expect(user.subscriptions.last.stripe_subscription_id).to eq('sub_123')
    end
  end
end
