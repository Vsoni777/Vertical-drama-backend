class StripeSubscriptionService
  PRICE_MAP = {
    "monthly" => ENV['STRIPE_PRICE_MONTHLY'],
    "yearly"  => ENV['STRIPE_PRICE_YEARLY']
  }.freeze

  def initialize(user)
    @user = user
  end

  def create_subscription(plan)
    price_value = PRICE_MAP[plan]
    raise ArgumentError, "Unknown plan or missing price id" unless price_value.present?

    resolved_price_id = resolve_price_id(plan, price_value)

    customer = ensure_customer

    subscription = Stripe::Subscription.create({
      customer: customer.id,
      items: [{ price: resolved_price_id }],
      expand: ['latest_invoice.payment_intent']
    })

    subscription
  end

  def resolve_price_id(plan, value)
    return value if value.to_s.start_with?("price_")

    unit_amount = value.to_i
    raise ArgumentError, "Invalid numeric price for plan #{plan}" unless unit_amount > 0

    interval = plan == "yearly" ? "year" : "month"

    product_id = ENV['STRIPE_PRODUCT_ID']
    if product_id.blank?
      product = Stripe::Product.create(name: "VerticalDrama Subscriptions")
      product_id = product.id
    end

    price = Stripe::Price.create({
      unit_amount: unit_amount,
      currency: (ENV['STRIPE_CURRENCY'] || 'usd'),
      recurring: { interval: interval },
      product: product_id
    })

    price.id
  end

  def cancel_subscription(stripe_subscription_id)
    return unless stripe_subscription_id.present?

    Stripe::Subscription.update(stripe_subscription_id, {cancel_at_period_end: true})
  end

  private

  def ensure_customer
    if @user.respond_to?(:stripe_customer_id) && @user.stripe_customer_id.present?
      Stripe::Customer.retrieve(@user.stripe_customer_id)
    else
      customer = Stripe::Customer.create({
        email: @user.email,
        metadata: { user_id: @user.id }
      })
      if @user.respond_to?(:stripe_customer_id)
        @user.update_column(:stripe_customer_id, customer.id)
      end
      customer
    end
  end
end
