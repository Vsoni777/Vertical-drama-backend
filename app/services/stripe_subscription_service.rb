class StripeSubscriptionService
  def initialize(user)
    @user = user
  end

  def ensure_customer
    return retrieve_existing_customer if @user.stripe_customer_id.present?

    customer = Stripe::Customer.create(
      email: @user.email,
      metadata: {
        user_id: @user.id.to_s
      }
    )

    @user.update!(
      stripe_customer_id: customer.id
    )

    customer
  end

  def resolve_price_id(plan, price_cents)
    # Create or retrieve a price from Stripe based on the plan
    # In production, you'd typically have pre-created prices in Stripe
    # For now, we'll use price_data directly in checkout
    return { price_data: build_price_data(plan, price_cents) }
  end

  def cancel_subscription(stripe_subscription_id)
    return if stripe_subscription_id.blank?

    Stripe::Subscription.update(
      stripe_subscription_id,
      {
        cancel_at_period_end: true
      }
    )
  end

  private

  def build_price_data(plan, price_cents)
    {
      currency: ENV.fetch("STRIPE_CURRENCY", "usd"),
      unit_amount: (price_cents * 100).to_i,
      product_data: {
        name: "Vertical Drama - #{plan.capitalize} Subscription",
        description: "Access to premium episodes"
      },
      recurring: {
        interval: plan == "monthly" ? "month" : "year",
        interval_count: 1
      }
    }
  end

  def retrieve_existing_customer
    Stripe::Customer.retrieve(
      @user.stripe_customer_id
    )
  rescue Stripe::InvalidRequestError => e
    Rails.logger.warn(
      "[Stripe] Customer #{@user.stripe_customer_id} " \
      "could not be retrieved: #{e.message}"
    )

    @user.update!(stripe_customer_id: nil)

    ensure_customer
  end
end