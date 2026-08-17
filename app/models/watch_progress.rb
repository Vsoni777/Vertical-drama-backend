class WatchProgress < ApplicationRecord
  belongs_to :user
  belongs_to :episode
  belongs_to :series

  validates :user_id, uniqueness: { scope: :episode_id }
  validates :progress_seconds, numericality: { greater_than_or_equal_to: 0 }
end
