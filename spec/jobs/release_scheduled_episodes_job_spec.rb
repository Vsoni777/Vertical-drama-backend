require 'rails_helper'

RSpec.describe ReleaseScheduledEpisodesJob, type: :job do
  describe '#perform' do
    let!(:series) { create(:series) }
    let!(:ready_episode) { create(:episode, series: series, locked: true, published_at: 1.hour.ago.to_s) }
    let!(:future_episode) { create(:episode, series: series, locked: true, published_at: 1.hour.from_now.to_s) }
    let!(:no_publish_date_episode) { create(:episode, series: series, locked: true, published_at: nil) }

    it 'unlocks episodes whose published_at is in the past' do
      expect {
        described_class.new.perform
      }.to change { ready_episode.reload.locked }.from(true).to(false)

      expect(future_episode.reload.locked).to be(true)
      expect(no_publish_date_episode.reload.locked).to be(true)
    end
  end
end
