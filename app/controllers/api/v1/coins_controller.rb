class Api::V1::CoinsController < Api::BaseController
  PACKS = {
    "small"  => { coins: 50,  price_cents: 299  },
    "medium" => { coins: 120, price_cents: 599  },
    "large"  => { coins: 300, price_cents: 1199 }
  }.freeze

  def reward_status
    claimed_today = current_user.coin_transactions
                                .where(transaction_type: :reward, description: "Daily login reward")
                                .where("created_at >= ?", Time.current.beginning_of_day)
                                .exists?
    render json: { data: { daily_login_claimed: claimed_today } }
  end

  def balance
    render json: {
      data: {
        coin_balance: current_user.coin_balance,
        transactions: current_user.coin_transactions.order(created_at: :desc).limit(20).map do |t|
          { id: t.id, amount: t.amount, type: t.transaction_type, description: t.description, created_at: t.created_at }
        end
      }
    }
  end

  def purchase
    pack = params[:pack].to_s
    return render(json: { error: "Invalid pack" }, status: :unprocessable_entity) unless PACKS.key?(pack)

    pack_info = PACKS[pack]

    if ENV["STRIPE_SECRET_KEY"].present?
      begin
        session = Stripe::Checkout::Session.create(
          mode:                 "payment",
          payment_method_types: [ "card" ],
          line_items: [
            {
              price_data: {
                currency:     ENV.fetch("STRIPE_CURRENCY", "usd"),
                unit_amount:  pack_info[:price_cents],
                product_data: {
                  name:        "◉ #{pack_info[:coins]} Coins (#{pack.capitalize} Pack)",
                  description: "Virtual coins for unlocking premium episodes"
                }
              },
              quantity: 1
            }
          ],
          metadata: {
            user_id: current_user.id,
            pack:    pack
          },
          success_url: "#{ENV.fetch('FRONT_URL', 'https://vertical-drama-five.vercel.app')}/coins?success=true&session_id={CHECKOUT_SESSION_ID}",
          cancel_url:  "#{ENV.fetch('FRONT_URL', 'https://vertical-drama-five.vercel.app')}/coins?canceled=true"
        )

        render json: {
          data: {
            checkout_url: session.url,
            session_id:   session.id,
            mode:         "stripe"
          }
        }, status: :created
      rescue Stripe::StripeError => e
        Rails.logger.error("[Stripe] Coin checkout error: #{e.message}")
        render json: { error: "Payment could not be initiated. Try again." }, status: :bad_gateway
      end

    else
      coins = pack_info[:coins]
      current_user.coin_transactions.create!(
        amount:           coins,
        transaction_type: :purchase,
        description:      "Purchased #{coins} coins (#{pack} pack) — dev mode"
      )
      render json: {
        data: {
          coins_added:  coins,
          coin_balance: current_user.reload.coin_balance,
          mode:         "dev"
        }
      }, status: :created
    end
  end

  def verify_purchase
    session_id = params[:session_id].to_s
    return render(json: { error: "Missing session_id" }, status: :bad_request) if session_id.blank?

    begin
      session = Stripe::Checkout::Session.retrieve(session_id)
    rescue Stripe::StripeError => e
      return render json: { error: e.message }, status: :bad_gateway
    end

    unless session.metadata["user_id"].to_i == current_user.id &&
           session.payment_status == "paid"
      return render json: { error: "Payment not completed" }, status: :payment_required
    end

    pack      = session.metadata["pack"]
    pack_info = PACKS[pack]
    return render(json: { error: "Unknown pack" }, status: :unprocessable_entity) unless pack_info

    description = "Stripe Checkout Session #{session_id} - Purchased #{pack_info[:coins]} coins (#{pack} pack)"
    unless current_user.coin_transactions.exists?(description: description)
      current_user.coin_transactions.create!(
        amount:           pack_info[:coins],
        transaction_type: :purchase,
        description:      description
      )
    end

    render json: {
      data: {
        coins_added:  pack_info[:coins],
        coin_balance: current_user.reload.coin_balance
      }
    }
  end

  def reward
    type = params[:reward_type].to_s
    reward_config = {
      "daily_login" => { amount: 5,  description: "Daily login reward" },
      "watch_ad"    => { amount: 10, description: "Rewarded ad watch" },
      "referral"    => { amount: 30, description: "Referral reward" }
    }

    config = reward_config[type]
    return render(json: { error: "Invalid reward type" }, status: :unprocessable_entity) unless config

    if type == "daily_login"
      already_claimed = current_user.coin_transactions
                                    .where(transaction_type: :reward, description: config[:description])
                                    .where("created_at >= ?", Time.current.beginning_of_day)
                                    .exists?
      return render(json: { error: "Already claimed today" }, status: :unprocessable_entity) if already_claimed
    end

    current_user.coin_transactions.create!(
      amount:           config[:amount],
      transaction_type: :reward,
      description:      config[:description]
    )

    render json: {
      data: {
        coins_earned: config[:amount],
        coin_balance: current_user.reload.coin_balance
      }
    }
  end
end
