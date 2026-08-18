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

    return render(json: { error: "Already subscribed" }, status: :unprocessable_entity) if current_user.subscriptions.active.exists?

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
        success_url: "#{ENV.fetch('FRONT_URL', 'https://vertical-drama-five.vercel.app')}/membership?success=true&session_id={CHECKOUT_SESSION_ID}",
        cancel_url: "#{ENV.fetch('FRONT_URL', 'https://vertical-drama-five.vercel.app')}/membership?canceled=true",
        subscription_data: {
          metadata: {
            user_id: current_user.id,
            plan: plan
          }
        }
      )

      render json: { data: { checkout_url: session.url, session_id: session.id } }, status: :created
    end
  end

  def verify_subscription
    session_id = params[:session_id].to_s
    return render(json: { error: "Missing session_id" }, status: :bad_request) if session_id.blank?

    begin
      session = Stripe::Checkout::Session.retrieve(session_id)
    rescue Stripe::StripeError => e
      return render json: { error: e.message }, status: :bad_gateway
    end

    plan = session.metadata["plan"]
    return render(json: { error: "Invalid plan" }, status: :unprocessable_entity) unless PLANS.key?(plan)

    description = "Stripe Subscription Session #{session_id}"

    unless current_user.subscriptions.active.exists?

      subscription = current_user.subscriptions.create!(
        plan:                  plan,
        status:                :active,
        started_at:            Time.current,
        ends_at:               Time.current + PLANS[plan][:duration],
        stripe_subscription_id: session.subscription
      )
    else
      subscription = current_user.subscriptions.find_by(stripe_subscription_id: session.subscription)
    end

    render json: { data: subscription_json(subscription) }
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
