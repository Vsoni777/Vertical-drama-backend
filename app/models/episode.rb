class Episode < ApplicationRecord
  belongs_to :series
  has_many :episode_unlocks,  dependent: :destroy
  has_many :watch_progresses, dependent: :destroy

  enum :video_status, {
    pending:    0,
    uploading:  1,
    processing: 2,
    ready:      3,
    errored:    4
  }, default: :pending

  validates :title, :episode_number, presence: true
  validates :episode_number, uniqueness: { scope: :series_id }
  validates :coin_cost, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  scope :ordered,    -> { order(:episode_number) }
  scope :published,  -> { where("scheduled_at IS NULL OR scheduled_at <= ?", Time.current) }

  def streamable?
    ready? && mux_playback_id.present?
  end

  def free?
    !locked?
  end

  def published?
    scheduled_at.nil? || scheduled_at <= Time.current
  end
end
