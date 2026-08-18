class Webhooks::StripeController < ActionController::Base
  skip_before_action :verify_authenticity_token
  protect_from_forgery with: :null_session

  def create
    payload = request.body.read
    signature = request.env["HTTP_STRIPE_SIGNATURE"]
    endpoint_secret = ENV["STRIPE_WEBHOOK_SECRET"]

    begin
      unless endpoint_secret.present?
        Rails.logger.error("[Stripe webhook] STRIPE_WEBHOOK_SECRET is missing")
        return render json: { error: "Webhook not configured" }, status: :internal_server_error
      end

      event = Stripe::Webhook.construct_event(
        payload,
        signature,
        endpoint_secret
      )
    rescue JSON::ParserError
      return render json: { error: "Invalid payload" }, status: :bad_request
    rescue Stripe::SignatureVerificationError
      return render json: { error: "Invalid signature" }, status: :bad_request
    rescue StandardError => e
      Rails.logger.error(
        "[Stripe webhook] Failed to construct event: #{e.class}: #{e.message}"
      )

      return render json: { error: "Invalid webhook" }, status: :bad_request
    end

    Rails.logger.info(
      "[Stripe webhook] received " \
      "type=#{event.type} " \
      "id=#{event.id}"
    )

    begin
      handle_event(event)
    rescue StandardError => e
      Rails.logger.error(
        "[Stripe webhook] Processing failed " \
        "event=#{event.id} " \
        "type=#{event.type} " \
        "error=#{e.class}: #{e.message}"
      )

      Rails.logger.error(e.backtrace.first(10).join("\n"))
      return render json: { error: "Webhook processing failed" }, status: :internal_server_error
    end

    render json: { ok: true }, status: :ok
  end

  private

  def handle_event(event)
    case event.type
    when "checkout.session.completed"
      handle_checkout_session_completed(event.data.object)

    when "customer.subscription.created",
         "customer.subscription.updated"
      handle_subscription_updated(event.data.object)

    when "customer.subscription.deleted"
      handle_subscription_deleted(event.data.object)

    when "invoice.payment_succeeded"
      handle_invoice_payment_succeeded(event.data.object)

    when "invoice.payment_failed"
      handle_invoice_payment_failed(event.data.object)

    else
      Rails.logger.info(
        "[Stripe webhook] Ignoring event type=#{event.type}"
      )
    end
  end

  def handle_checkout_session_completed(session)
    metadata = session.metadata.to_h

    Rails.logger.info(
      "[Stripe webhook] checkout.session.completed " \
      "session=#{session.id} " \
      "mode=#{session.mode} " \
      "metadata=#{metadata}"
    )

    if metadata["plan"].present?
      handle_subscription_checkout(session)
    elsif metadata["pack"].present?
      handle_coin_checkout(session)
    else
      Rails.logger.warn(
        "[Stripe webhook] checkout session has no plan or pack " \
        "session=#{session.id}"
      )
    end
  end

  def handle_subscription_checkout(session)
    user_id = session.metadata["user_id"]
    plan = session.metadata["plan"]
    stripe_subscription_id = session.subscription

    return if user_id.blank?
    return if plan.blank?
    return if stripe_subscription_id.blank?

    user = User.find_by(id: user_id)

    unless user
      Rails.logger.error(
        "[Stripe webhook] User not found user_id=#{user_id}"
      )
      return
    end

    unless subscription_plan_valid?(plan)
      Rails.logger.error(
        "[Stripe webhook] Invalid plan=#{plan} " \
        "session=#{session.id}"
      )
      return
    end

    stripe_subscription =
      Stripe::Subscription.retrieve(stripe_subscription_id)

    subscription =
      user.subscriptions.find_or_initialize_by(
        stripe_subscription_id: stripe_subscription.id
      )

    subscription.plan = plan
    subscription.status =
      stripe_subscription_active?(stripe_subscription) ? :active : :cancelled

    subscription.started_at =
      stripe_timestamp(stripe_subscription.current_period_start) ||
      subscription.started_at ||
      Time.current

    subscription.ends_at =
      stripe_timestamp(stripe_subscription.current_period_end)

    subscription.save!

    Rails.logger.info(
      "[Stripe webhook] Subscription synced " \
      "user=#{user.id} " \
      "subscription=#{subscription.id} " \
      "stripe_subscription=#{stripe_subscription.id} " \
      "plan=#{plan}"
    )
  end


  def handle_subscription_updated(stripe_subscription)
    stripe_subscription_id = stripe_subscription.id
    customer_id = stripe_subscription.customer

    user = User.find_by(
      stripe_customer_id: customer_id
    )

    unless user
      Rails.logger.warn(
        "[Stripe webhook] User not found for customer=#{customer_id}"
      )
      return
    end

    metadata = stripe_subscription.metadata.to_h

    plan = metadata["plan"]

    subscription =
      user.subscriptions.find_or_initialize_by(
        stripe_subscription_id: stripe_subscription_id
      )

    subscription.plan = plan if plan.present?

    subscription.status =
      stripe_subscription_active?(stripe_subscription) ? :active : :cancelled

    subscription.started_at =
      stripe_timestamp(stripe_subscription.current_period_start) ||
      subscription.started_at ||
      Time.current

    subscription.ends_at =
      stripe_timestamp(stripe_subscription.current_period_end)

    subscription.save!

    Rails.logger.info(
      "[Stripe webhook] Subscription updated " \
      "user=#{user.id} " \
      "stripe_subscription=#{stripe_subscription_id} " \
      "stripe_status=#{stripe_subscription.status} " \
      "local_status=#{subscription.status}"
    )
  end


  def handle_subscription_deleted(stripe_subscription)
    subscription =
      Subscription.find_by(
        stripe_subscription_id: stripe_subscription.id
      )

    unless subscription
      Rails.logger.warn(
        "[Stripe webhook] Local subscription not found " \
        "stripe_subscription=#{stripe_subscription.id}"
      )
      return
    end

    subscription.update!(
      status: :cancelled,
      ends_at: stripe_timestamp(
        stripe_subscription.ended_at
      ) || Time.current
    )

    Rails.logger.info(
      "[Stripe webhook] Subscription cancelled " \
      "subscription=#{subscription.id}"
    )
  end

  def handle_invoice_payment_succeeded(invoice)
    stripe_subscription_id = invoice.subscription

    return if stripe_subscription_id.blank?

    subscription =
      Subscription.find_by(
        stripe_subscription_id: stripe_subscription_id
      )

    unless subscription
      Rails.logger.warn(
        "[Stripe webhook] Local subscription not found for invoice " \
        "stripe_subscription=#{stripe_subscription_id}"
      )
      return
    end

    stripe_subscription =
      Stripe::Subscription.retrieve(stripe_subscription_id)

    subscription.update!(
      status: :active,
      ends_at: stripe_timestamp(
        stripe_subscription.current_period_end
      )
    )

    Rails.logger.info(
      "[Stripe webhook] Invoice payment succeeded " \
      "subscription=#{subscription.id}"
    )
  end

  def handle_invoice_payment_failed(invoice)
    stripe_subscription_id = invoice.subscription

    return if stripe_subscription_id.blank?

    subscription =
      Subscription.find_by(
        stripe_subscription_id: stripe_subscription_id
      )

    return unless subscription

    Rails.logger.warn(
      "[Stripe webhook] Invoice payment failed " \
      "subscription=#{subscription.id} " \
      "invoice=#{invoice.id}"
    )
  end

def handle_coin_checkout(session)
  return unless session.payment_status == "paid"

  metadata = session.metadata.to_h

  user_id = metadata["user_id"]
  pack = metadata["pack"]

  return if user_id.blank?
  return if pack.blank?

  user = User.find_by(id: user_id)

  unless user
    Rails.logger.error(
      "[Stripe webhook] User not found user_id=#{user_id}"
    )
    return
  end

  pack_info = Coins::PACKS[pack]

  unless pack_info
    Rails.logger.error(
      "[Stripe webhook] Invalid coin pack=#{pack}"
    )
    return
  end

  coins = pack_info[:coins]

  description =
    "Stripe Checkout Session #{session.id} - " \
    "Purchased #{coins} coins (#{pack} pack)"

  if user.coin_transactions.exists?(description: description)
    Rails.logger.info(
      "[Stripe webhook] Coin purchase already processed " \
      "session=#{session.id}"
    )
    return
  end

  user.coin_transactions.create!(
    amount: coins,
    transaction_type: :purchase,
    description: description
  )

  Rails.logger.info(
    "[Stripe webhook] Added #{coins} coins " \
    "user=#{user.id} " \
    "pack=#{pack} " \
    "session=#{session.id}"
  )
end

  def subscription_plan_valid?(plan)
    %w[monthly yearly].include?(plan)
  end

  def stripe_subscription_active?(subscription)
    %w[active trialing].include?(subscription.status)
  end

  def stripe_timestamp(timestamp)
    return nil if timestamp.blank?

    Time.at(timestamp.to_i)
  end
end