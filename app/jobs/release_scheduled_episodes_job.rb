class ReleaseScheduledEpisodesJob < ApplicationJob
  queue_as :default

  def perform
    episodes = Episode.where(locked: true).where.not(published_at: nil).where('published_at <= ?', Time.current)
    episodes.find_each do |ep|
      ep.update!(locked: false)
      Rails.logger.info("[ReleaseScheduledEpisodesJob] released episode id=#{ep.id} title=#{ep.title}")
    end
  end
end
