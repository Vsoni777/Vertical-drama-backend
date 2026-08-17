require 'rails_helper'

RSpec.describe Api::V1::UsersController, type: :controller do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'GET #me' do
    it 'returns the current user profile' do
      get :me
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['data']['id']).to eq(user.id)
      expect(json['data']['email']).to eq(user.email)
    end
  end
end
