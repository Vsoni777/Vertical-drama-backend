require 'rails_helper'

RSpec.describe Api::V1::WatchProgressController, type: :controller do
  let(:user) { create(:user) }
  let(:series) { create(:series) }
  let(:episode) { create(:episode, series: series) }

  before { sign_in user }

  describe 'POST #update' do
    it 'creates or updates watch progress' do
      post :update, params: { series_id: series.id, episode_id: episode.id, progress_seconds: 30 }
      expect(response).to have_http_status(:success)
      
      progress = user.watch_progresses.find_by(episode_id: episode.id)
      expect(progress.progress_seconds).to eq(30)
      expect(progress.completed).to be(false)
    end
    
    it 'marks as completed if completed param is true' do
      post :update, params: { series_id: series.id, episode_id: episode.id, progress_seconds: 95, completed: true }
      expect(response).to have_http_status(:success)
      
      progress = user.watch_progresses.find_by(episode_id: episode.id)
      expect(progress.completed).to be(true)
    end
  end
end
