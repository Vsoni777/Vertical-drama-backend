require 'rails_helper'

RSpec.describe Webhooks::StripeController, type: :controller do
  let(:secret) { 'test_stripe_secret' }
  let(:user) { create(:user, stripe_customer_id: 'cus_123') }
  let(:payload) { { id: 'evt_123', type: 'customer.subscription.updated', data: { object: { id: 'sub_123', customer: user.stripe_customer_id, status: 'active', current_period_end: (Time.current + 1.month).to_i } } }.to_json }
  let(:signature) { generate_stripe_signature(payload, secret) }

  def generate_stripe_signature(payload, secret)
    time = Time.now
    timestamp = time.to_i
    signature = Stripe::Webhook::Signature.compute_signature(time, payload, secret)
    "t=\#{timestamp},v1=\#{signature}"
  end

  before do
    ENV['STRIPE_WEBHOOK_SECRET'] = secret
  end

  after do
    ENV['STRIPE_WEBHOOK_SECRET'] = nil
  end

  describe 'POST #create' do
    context 'with valid signature' do
      before do
        allow(Stripe::Webhook).to receive(:construct_event) do |payload, sig, secret|
          JSON.parse(payload, symbolize_names: true)
        end
      end

      it 'handles customer.subscription.updated' do
      post :create, body: payload
      expect(response).to have_http_status(:success)
      subscription = user.subscriptions.last
      expect(subscription.stripe_subscription_id).to eq('sub_123')
      expect(subscription.status).to eq('active')
    end

    it 'handles customer.subscription.deleted' do
      create(:subscription, user: user, stripe_subscription_id: 'sub_delete')
      delete_payload = { type: 'customer.subscription.deleted', data: { object: { id: 'sub_delete' } } }.to_json
      request.headers['HTTP_STRIPE_SIGNATURE'] = generate_stripe_signature(delete_payload, secret)

      post :create, body: delete_payload
      expect(response).to have_http_status(:success)
      subscription = user.subscriptions.last
      expect(subscription.status).to eq('cancelled')
    end
    
    it 'handles checkout.session.completed for coins' do
      checkout_payload = { type: 'checkout.session.completed', data: { object: { id: 'cs_test', metadata: { user_id: user.id, pack: 'small' } } } }.to_json
      request.headers['HTTP_STRIPE_SIGNATURE'] = generate_stripe_signature(checkout_payload, secret)

      post :create, body: checkout_payload
      expect(response).to have_http_status(:success)
      transaction = user.coin_transactions.last
      expect(transaction.amount).to eq(50)
      expect(transaction.description).to include('small pack')
      end
    end

    context 'with invalid signature' do
      it 'returns bad request' do
        request.headers['HTTP_STRIPE_SIGNATURE'] = "t=\#{Time.now.to_i},v1=invalid"
        post :create, body: payload
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
