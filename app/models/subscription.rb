class Subscription < ApplicationRecord
  belongs_to :user

  enum :status, { active: 0, cancelled: 1, expired: 2 }, default: :active
  enum :plan,   { monthly: "monthly", yearly: "yearly" }

  validates :plan, presence: true

  scope :active_for, ->(user) { where(user: user, status: :active).where("ends_at IS NULL OR ends_at > ?", Time.current) }

  def active?
    status == "active" && (ends_at.nil? || ends_at > Time.current)
  end
end
