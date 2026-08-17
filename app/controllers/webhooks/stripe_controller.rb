class Webhooks::StripeController < ActionController::Base
  # Webhooks are POSTed from Stripe servers (or from local dev tools).
  # They don't include Rails CSRF tokens, so skip authenticity verification.
  skip_before_action :verify_authenticity_token
  protect_from_forgery with: :null_session

  def create
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    endpoint_secret = ENV['STRIPE_WEBHOOK_SECRET']

    begin
      event = if endpoint_secret.present?
                Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
              else
                JSON.parse(payload, symbolize_names: true)
              end
      evt_type = event[:type] || event['type']
      evt_obj  = (event[:data] || event['data']) && (event[:data][:object] || event['data']['object'])
      Rails.logger.info("[Stripe webhook] received event=#{evt_type} id=#{event[:id] || event['id']} object=#{evt_obj && (evt_obj[:id] || evt_obj['id'])} metadata=#{evt_obj && (evt_obj[:metadata] || evt_obj['metadata'])}")
    rescue JSON::ParserError => e
      render status: 400, json: { error: "Invalid payload" } and return
    rescue Stripe::SignatureVerificationError => e
      render status: 400, json: { error: "Invalid signature" } and return
    end

    handle_event(event)

    render json: { ok: true }
  end

  private

  def handle_event(event)
    type = event[:type] || event['type']
    data = event[:data] || event['data']
    obj = data && (data[:object] || data['object'])

    case type
    when 'customer.subscription.updated', 'customer.subscription.created'
      handle_subscription_updated(obj)
    when 'customer.subscription.deleted'
      handle_subscription_deleted(obj)
    when 'invoice.payment_succeeded'
      if (obj[:subscription] || obj['subscription']).present?
        handle_invoice_payment(obj)
      else
        Rails.logger.info("[Stripe webhook] invoice.payment_succeeded without subscription, ignoring. id=#{obj && (obj[:id] || obj['id'])}")
      end
    when 'checkout.session.completed'
      metadata = obj && (obj[:metadata] || obj['metadata'])
      if metadata && (metadata['pack'] || metadata[:pack])
        handle_checkout_session_completed(obj)
      else
        Rails.logger.info("[Stripe webhook] checkout.session.completed without coin metadata, ignoring. id=#{obj && (obj[:id] || obj['id'])}")
      end
    end
  end

  def handle_subscription_updated(obj)
    stripe_sub_id = obj[:id] || obj['id']
    customer_id = obj[:customer] || obj['customer']
    status = obj[:status] || obj['status']
    current_period_end_raw = obj[:current_period_end] || obj['current_period_end']
    current_period_end = current_period_end_raw ? Time.at(current_period_end_raw.to_i) : nil
    metadata = obj[:metadata] || obj['metadata'] || {}
    plan = metadata[:plan] || metadata['plan'] || "monthly"

    user = User.find_by(stripe_customer_id: customer_id)
    return unless user

    sub = user.subscriptions.find_or_initialize_by(stripe_subscription_id: stripe_sub_id)
    sub.plan = plan if sub.new_record? || plan.present?
    sub.status = (status == 'active' || status == 'trialing') ? :active : :cancelled
    sub.ends_at = current_period_end
    sub.started_at ||= Time.current
    sub.save!
  end

  def handle_subscription_deleted(obj)
    stripe_sub_id = obj[:id] || obj['id']
    sub = Subscription.find_by(stripe_subscription_id: stripe_sub_id)
    return unless sub

    sub.update!(status: :cancelled, ends_at: Time.current)
  end

  def handle_invoice_payment(obj)
    stripe_sub_id = obj[:subscription] || obj['subscription']
    return unless stripe_sub_id

    sub = Subscription.find_by(stripe_subscription_id: stripe_sub_id)
    return unless sub

    current_period_end = obj[:lines] && obj[:lines][:data] && obj[:lines][:data].first && obj[:lines][:data].first[:period] && obj[:lines][:data].first[:period][:end]
    if current_period_end
      sub.update!(status: :active, ends_at: Time.at(current_period_end.to_i))
    else
      sub.update!(status: :active)
    end
  end

  def handle_checkout_session_completed(obj)
    session_id = obj[:id] || obj['id']
    metadata = obj[:metadata] || obj['metadata'] || {}
    user_id = metadata['user_id'] || metadata[:user_id]
    pack = metadata['pack'] || metadata[:pack]

    return unless user_id && pack

    user = User.find_by(id: user_id)
    return unless user

    packs = {
      "small"  => { coins: 50,  price_cents: 299  },
      "medium" => { coins: 120, price_cents: 599  },
      "large"  => { coins: 300, price_cents: 1199 }
    }

    pack_info = packs[pack]
    return unless pack_info

    coins = pack_info[:coins]

    description = "Stripe Checkout Session #{session_id} - Purchased #{coins} coins (#{pack} pack)"
    return if user.coin_transactions.exists?(description: description)

    user.coin_transactions.create!(
      amount:           coins,
      transaction_type: :purchase,
      description:      description
    )
  end
end
