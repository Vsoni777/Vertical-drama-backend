require 'rails_helper'

RSpec.describe Api::V1::EpisodesController, type: :controller do
  let(:admin) { create(:user, :admin) }
  let(:viewer) { create(:user) }
  let(:series) { create(:series) }
  let(:episode) { create(:episode, series: series) }

  describe 'GET #index' do
    before { sign_in viewer }

    it 'returns episodes for a series' do
      create_list(:episode, 3, series: series)
      get :index, params: { series_id: series.id }
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['data'].size).to eq(3)
    end
  end

  describe 'GET #show' do
    before { sign_in viewer }

    it 'returns the episode' do
      get :show, params: { series_id: series.id, id: episode.id }
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['data']['id']).to eq(episode.id)
    end
  end

  describe 'POST #create' do
    context 'as admin' do
      before do
        sign_in admin
        allow(MuxVideo).to receive(:create_direct_upload!).and_return('id' => 'upload_123', 'url' => 'http://upload.url')
      end

      it 'creates a new episode' do
        post :create, params: { series_id: series.id, episode: { title: 'E1', episode_number: 1 } }
        expect(response).to have_http_status(:created)
        expect(Episode.count).to eq(1)
      end
    end

    context 'as viewer' do
      before { sign_in viewer }

      it 'returns forbidden' do
        post :create, params: { series_id: series.id, episode: { title: 'E1', episode_number: 1 } }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PATCH #update' do
    context 'as admin' do
      before { sign_in admin }

      it 'updates the episode' do
        patch :update, params: { series_id: series.id, id: episode.id, episode: { title: 'Updated Title' } }
        expect(response).to have_http_status(:success)
        expect(episode.reload.title).to eq('Updated Title')
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:episode_to_delete) { create(:episode, series: series) }

    context 'as admin' do
      before { sign_in admin }

      it 'deletes the episode' do
        expect {
          delete :destroy, params: { series_id: series.id, id: episode_to_delete.id }
        }.to change(Episode, :count).by(-1)
        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
