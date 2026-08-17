require 'rails_helper'

RSpec.describe StripeSubscriptionService do
  let(:user) { create(:user) }
  let(:service) { described_class.new(user) }

  before do
    ENV['STRIPE_PRICE_MONTHLY'] = 'price_monthly123'
    ENV['STRIPE_PRICE_YEARLY'] = 'price_yearly123'
  end

  after do
    ENV['STRIPE_PRICE_MONTHLY'] = nil
    ENV['STRIPE_PRICE_YEARLY'] = nil
  end

  describe '#create_subscription' do
    it 'creates a stripe subscription' do
      customer_double = double(id: 'cus_123')
      allow(service).to receive(:ensure_customer).and_return(customer_double)
      allow(ENV).to receive(:[]).with('STRIPE_PRODUCT_ID').and_return(nil)
      allow(ENV).to receive(:[]).with('STRIPE_CURRENCY').and_return('usd')
      allow(Stripe::Product).to receive(:create).and_return(double(id: 'prod_123'))
      allow(Stripe::Price).to receive(:create).and_return(double(id: 'price_monthly123'))
      
      subscription_double = double(id: 'sub_123')
      allow(Stripe::Subscription).to receive(:create).with({
        customer: customer_double.id,
        items: [{ price: 'price_monthly123' }],
        expand: ['latest_invoice.payment_intent']
      }).and_return(subscription_double)
      
      subscription = service.create_subscription('monthly')
      expect(subscription.id).to eq('sub_123')
    end
  end

  describe '#cancel_subscription' do
    it 'cancels a stripe subscription' do
      allow(Stripe::Subscription).to receive(:update).with('sub_123', {cancel_at_period_end: true}).and_return(true)
      
      result = service.cancel_subscription('sub_123')
      expect(result).to be(true)
    end
  end
end
