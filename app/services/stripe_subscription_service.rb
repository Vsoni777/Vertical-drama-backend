class StripeSubscriptionService
  PRICE_MAP = {
    "monthly" => ENV["STRIPE_PRICE_MONTHLY"],
    "yearly"  => ENV["STRIPE_PRICE_YEARLY"]
  }.freeze

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

  def price_id_for(plan)
    price_id = PRICE_MAP[plan]

    unless price_id.present?
      raise ArgumentError,
            "Missing Stripe price ID for plan: #{plan}"
    end

    unless price_id.start_with?("price_")
      raise ArgumentError,
            "Invalid Stripe price ID for plan: #{plan}"
    end

    price_id
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

    create_customer
  end

  def create_customer
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
end