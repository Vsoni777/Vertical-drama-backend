class Api::V1::CoinsController < Api::BaseController
  PACKS = {
    "small" => {
      coins: 50,
      price_cents: 299
    },
    "medium" => {
      coins: 120,
      price_cents: 599
    },
    "large" => {
      coins: 300,
      price_cents: 1199
    }
  }.freeze

  REWARDS = {
    "daily_login" => {
      amount: 5,
      description: "Daily login reward"
    },
    "watch_ad" => {
      amount: 10,
      description: "Rewarded ad watch"
    },
    "referral" => {
      amount: 30,
      description: "Referral reward"
    }
  }.freeze

  def reward_status
    claimed_today = daily_login_claimed?

    render json: {
      data: {
        daily_login_claimed: claimed_today
      }
    }
  end

  def balance
    transactions = current_user
                    .coin_transactions
                    .order(created_at: :desc)
                    .limit(20)

    render json: {
      data: {
        coin_balance: current_user.coin_balance,
        transactions: transactions.map do |transaction|
          {
            id: transaction.id,
            amount: transaction.amount,
            type: transaction.transaction_type,
            description: transaction.description,
            created_at: transaction.created_at
          }
        end
      }
    }
  end

  def purchase
    return stripe_not_configured unless stripe_configured?

    pack = params[:pack].to_s
    pack_info = PACKS[pack]

    unless pack_info
      return render json: {
        error: "Invalid pack"
      }, status: :unprocessable_entity
    end

    begin
      session = Stripe::Checkout::Session.create(
        mode: "payment",
        payment_method_types: ["card"],

        line_items: [
          {
            price_data: {
              currency: ENV.fetch("STRIPE_CURRENCY", "usd"),
              unit_amount: pack_info[:price_cents],
              product_data: {
                name: "#{pack_info[:coins]} Coins (#{pack.capitalize} Pack)",
                description: "Virtual coins for unlocking premium episodes"
              }
            },
            quantity: 1
          }
        ],

        metadata: {
          user_id: current_user.id.to_s,
          pack: pack
        },

        success_url: success_url,
        cancel_url: cancel_url
      )

      render json: {
        data: {
          checkout_url: session.url,
          session_id: session.id,
          mode: "stripe"
        }
      }, status: :created

    rescue Stripe::StripeError => e
      Rails.logger.error(
        "[Stripe] Coin checkout error: #{e.class}: #{e.message}"
      )

      render json: {
        error: "Payment could not be initiated. Try again."
      }, status: :bad_gateway
    end
  end

  def reward
    reward_type = params[:reward_type].to_s
    config = REWARDS[reward_type]

    unless config
      return render json: {
        error: "Invalid reward type"
      }, status: :unprocessable_entity
    end

    if reward_type == "daily_login" && daily_login_claimed?
      return render json: {
        error: "Already claimed today"
      }, status: :unprocessable_entity
    end

    transaction = current_user.coin_transactions.create!(
      amount: config[:amount],
      transaction_type: :reward,
      description: config[:description]
    )

    render json: {
      data: {
        transaction_id: transaction.id,
        coins_earned: config[:amount],
        coin_balance: current_user.coin_balance
      }
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      error: e.message
    }, status: :unprocessable_entity
  end

  private

  def stripe_configured?
    ENV["STRIPE_SECRET_KEY"].present?
  end

  def stripe_not_configured
    render json: {
      error: "Stripe is not configured"
    }, status: :service_unavailable
  end

  def frontend_url
    ENV.fetch(
      "FRONT_URL",
      "https://vertical-drama-five.vercel.app"
    )
  end

  def success_url
    "#{frontend_url}/membership?success=true&session_id={CHECKOUT_SESSION_ID}"
  end

  def cancel_url
    "#{frontend_url}/membership?canceled=true"
  end

  def daily_login_claimed?
    current_user.coin_transactions
      .where(
        transaction_type: :reward,
        description: REWARDS["daily_login"][:description]
      )
      .where(
        "created_at >= ?",
        Time.current.beginning_of_day
      )
      .exists?
  end
end