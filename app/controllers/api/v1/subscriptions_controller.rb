class Api::V1::SubscriptionsController < Api::BaseController
  PLANS = {
    "monthly" => { price_cents: 7.99,  duration: 1.month  },
    "yearly"  => { price_cents: 59.99, duration: 1.year   }
  }.freeze

  def show
    subscription = current_user.subscriptions.find_by(status: :active)
    render json: { data: subscription_json(subscription) }
  end

  def create
    plan = params[:plan].to_s
    return render(json: { error: "Invalid plan" }, status: :unprocessable_entity) unless PLANS.key?(plan)

    current_user.subscriptions.active.update_all(status: :cancelled)

    if ENV['STRIPE_SECRET_KEY'].present?
      svc = StripeSubscriptionService.new(current_user)
      stripe_sub = svc.create_subscription(plan)

      started_at = Time.at(stripe_sub.current_period_start) if stripe_sub.respond_to?(:current_period_start)
      ends_at    = Time.at(stripe_sub.current_period_end)   if stripe_sub.respond_to?(:current_period_end)

      subscription = current_user.subscriptions.create!(
        plan:                  plan,
        status:                :active,
        started_at:            started_at || Time.current,
        ends_at:               ends_at || (Time.current + PLANS[plan][:duration]),
        stripe_subscription_id: stripe_sub.id
      )
    else
      subscription = current_user.subscriptions.create!(
        plan:       plan,
        status:     :active,
        started_at: Time.current,
        ends_at:    Time.current + PLANS[plan][:duration]
      )
    end

    render json: { data: subscription_json(subscription) }, status: :created
  end

  def checkout
    plan = params[:plan].to_s
    return render(json: { error: "Invalid plan" }, status: :unprocessable_entity) unless PLANS.key?(plan)

    if ENV['STRIPE_SECRET_KEY'].present?
      svc = StripeSubscriptionService.new(current_user)
      price_value = StripeSubscriptionService::PRICE_MAP[plan]
      price_id = svc.resolve_price_id(plan, price_value)
      customer = svc.send(:ensure_customer)

      session = Stripe::Checkout::Session.create(
        customer: customer.id,
        payment_method_types: ['card'],
        line_items: [{
          price: price_id,
          quantity: 1,
        }],
        mode: 'subscription',
        success_url: "#{ENV['FRONT_URL']}/dashboard?success=true&session_id={CHECKOUT_SESSION_ID}",
        cancel_url: "#{ENV['FRONT_URL']}/membership?canceled=true",
        subscription_data: {
          metadata: {
            plan: plan
          }
        }
      )

      render json: { data: { checkout_url: session.url } }
    else
      current_user.subscriptions.active.update_all(status: :cancelled)
      subscription = current_user.subscriptions.create!(
        plan:       plan,
        status:     :active,
        started_at: Time.current,
        ends_at:    Time.current + PLANS[plan][:duration]
      )
      render json: { data: { mode: 'dev', subscription: subscription_json(subscription) } }
    end
  end

  def destroy
    subscription = current_user.subscriptions.find_by(status: :active)
    return render(json: { error: "No active subscription" }, status: :not_found) unless subscription

    if subscription.stripe_subscription_id.present? && ENV['STRIPE_SECRET_KEY'].present?
      svc = StripeSubscriptionService.new(current_user)
      svc.cancel_subscription(subscription.stripe_subscription_id)
    end

    subscription.update!(status: :cancelled)
    render json: { message: "Subscription cancelled" }
  end

  private

  def subscription_json(sub)
    return nil unless sub

    {
      id:         sub.id,
      plan:       sub.plan,
      status:     sub.status,
      started_at: sub.started_at,
      ends_at:    sub.ends_at,
      active:     sub.active?
    }
  end
end
