class EpisodeUnlock < ApplicationRecord
  belongs_to :user
  belongs_to :episode

  validates :user_id, uniqueness: { scope: :episode_id, message: "already unlocked this episode" }
end
