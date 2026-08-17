class Api::V1::UsersController < Api::BaseController
  def me
    subscription = current_user.subscriptions
                               .where(status: :active)
                               .where("ends_at IS NULL OR ends_at >= ?", Time.current)
                               .order(created_at: :desc)
                               .first

    render json: {
      data: {
        id:            current_user.id,
        email:         current_user.email,
        role:          current_user.role,
        coin_balance:  current_user.coin_balance,
        subscribed:    current_user.active_subscription?,
        subscription:  subscription ? {
          plan:     subscription.plan,
          ends_at:  subscription.ends_at
        } : nil
      }
    }
  end
end
