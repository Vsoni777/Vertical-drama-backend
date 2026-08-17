class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  enum :role, { viewer: 0, admin: 1 }, default: :viewer

  has_many :subscriptions,     dependent: :destroy
  has_many :coin_transactions,  dependent: :destroy
  has_many :episode_unlocks,    dependent: :destroy
  has_many :unlocked_episodes,  through: :episode_unlocks, source: :episode
  has_many :watch_progresses,   dependent: :destroy

  def active_subscription?
    subscriptions.where(status: :active).where("ends_at IS NULL OR ends_at >= ?", Time.current).exists?
  end

  def unlocked?(episode)
    episode_unlocks.exists?(episode: episode)
  end

  def can_watch?(episode)
    return true  if episode.free?
    return true  if active_subscription?
    return true  if unlocked?(episode)

    false
  end
end
