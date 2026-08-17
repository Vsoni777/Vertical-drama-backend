class CoinTransaction < ApplicationRecord
  belongs_to :user

  enum :transaction_type, {
    purchase: 0,
    unlock:   1,
    reward:   2,
    refund:   3
  }, default: :purchase

  validates :amount, presence: true,
                     numericality: { other_than: 0 }

  after_create :update_user_balance

  private

  def update_user_balance
    user.with_lock do
      new_balance = user.coin_balance + amount
      raise ActiveRecord::Rollback, "Insufficient coins" if new_balance < 0

      user.update_columns(coin_balance: new_balance)
    end
  end
end
