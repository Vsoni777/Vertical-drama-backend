class Api::V1::SubscriptionsController < Api::BaseController
  PLANS = {
    "monthly" => {
      price: 7.99,
      duration: 1.month
    },
    "yearly" => {
      price: 59.99,
      duration: 1.year
    }
  }.freeze

  def show
    subscription = current_user.subscriptions.active.first
    render json: { data: subscription_json(subscription) }
  end

  def checkout
    return stripe_not_configured unless stripe_configured?

    plan = params[:plan].to_s

    unless PLANS.key?(plan)
      return render json: {
        error: "Invalid plan"
      }, status: :unprocessable_entity
    end

    if current_user.subscriptions.active.exists?
      return render json: {
        error: "Already subscribed"
      }, status: :unprocessable_entity
    end

    service = StripeSubscriptionService.new(current_user)
    customer = service.ensure_customer
    price_id = service.price_id_for(plan)

    session = Stripe::Checkout::Session.create(
          customer: customer.id, mode: "subscription",
          payment_method_types: ["card"],
          line_items: [ { price: price_id, quantity: 1 } ],
          metadata: { user_id: current_user.id.to_s, plan: plan },
          subscription_data: {
            metadata: {
              user_id: current_user.id.to_s,
              plan: plan
            }
          },
          success_url: "#{frontend_url}/membership?success=true",
          cancel_url: "#{frontend_url}/membership?canceled=true"
        )
    
    render json: {
      data: { checkout_url: session.url, session_id: session.id } }, status: :created
    rescue Stripe::StripeError => e
      render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    subscription = current_user.subscriptions.active.first

    return render json: { error: "No active subscription" }, status: :not_found unless subscription

    if stripe_configured? && subscription.stripe_subscription_id.present?
      StripeSubscriptionService.new(current_user).cancel_subscription(subscription.stripe_subscription_id)
    end

    subscription.update!(status: :cancelled)

    render json: { message: "Subscription cancelled" }, status: :ok
  rescue Stripe::StripeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def frontend_url
    ENV.fetch(
      "FRONT_URL",
      "https://vertical-drama-five.vercel.app"
    )
  end

  def stripe_configured?
    ENV["STRIPE_SECRET_KEY"].present?
  end

  def stripe_not_configured
    render json: {
      error: "Stripe not configured"
    }, status: :unprocessable_entity
  end

  def subscription_json(subscription)
    return nil unless subscription

    {
      id: subscription.id,
      plan: subscription.plan,
      status: subscription.status,
      started_at: subscription.started_at,
      ends_at: subscription.ends_at,
      active: subscription.active?,
      stripe_subscription_id: subscription.stripe_subscription_id
    }
  end
end