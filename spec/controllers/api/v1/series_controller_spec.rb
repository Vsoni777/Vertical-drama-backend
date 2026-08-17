require 'rails_helper'

RSpec.describe Api::V1::SeriesController, type: :controller do
  let(:admin) { create(:user, :admin) }
  let(:viewer) { create(:user) }
  let(:series) { create(:series) }

  describe 'GET #index' do
    before { sign_in viewer }

    it 'returns a list of series' do
      create_list(:series, 3)
      get :index
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['data'].size).to eq(3)
    end
  end

  describe 'GET #show' do
    before { sign_in viewer }

    it 'returns a single series' do
      get :show, params: { id: series.id }
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['data']['id']).to eq(series.id)
    end
  end

  describe 'POST #create' do
    context 'as admin' do
      before { sign_in admin }

      it 'creates a new series' do
        post :create, params: { series: { title: 'New Series', status: 'ongoing' } }
        expect(response).to have_http_status(:created)
        expect(Series.count).to eq(1)
      end
    end

    context 'as viewer' do
      before { sign_in viewer }

      it 'returns forbidden' do
        post :create, params: { series: { title: 'New Series', status: 'ongoing' } }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PATCH #update' do
    context 'as admin' do
      before { sign_in admin }

      it 'updates the series' do
        patch :update, params: { id: series.id, series: { title: 'Updated Title' } }
        expect(response).to have_http_status(:success)
        expect(series.reload.title).to eq('Updated Title')
      end
    end

    context 'as viewer' do
      before { sign_in viewer }

      it 'returns forbidden' do
        patch :update, params: { id: series.id, series: { title: 'Updated Title' } }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:series_to_delete) { create(:series) }

    context 'as admin' do
      before { sign_in admin }

      it 'deletes the series' do
        expect {
          delete :destroy, params: { id: series_to_delete.id }
        }.to change(Series, :count).by(-1)
        expect(response).to have_http_status(:no_content)
      end
    end

    context 'as viewer' do
      before { sign_in viewer }

      it 'returns forbidden' do
        delete :destroy, params: { id: series_to_delete.id }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
