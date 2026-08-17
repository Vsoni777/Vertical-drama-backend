require 'rails_helper'

RSpec.describe Webhooks::MuxController, type: :controller do
  let(:episode) { create(:episode, mux_asset_id: nil, video_status: :processing) }
  let(:secret) { 'test_secret' }
  let(:timestamp) { Time.current.to_i.to_s }
  let(:payload) { { data: { passthrough: episode.id.to_s, id: 'new_asset_id', playback_ids: [{ policy: 'signed', id: 'new_playback_id' }] }, type: 'video.asset.ready' }.to_json }
  let(:signature) { OpenSSL::HMAC.hexdigest('SHA256', secret, "\#{timestamp}.\#{payload}") }

  before do
    ENV['MUX_PLAYBACK_POLICY'] = 'signed'
  end

  after do
    ENV['MUX_WEBHOOK_SECRET'] = nil
    ENV['MUX_PLAYBACK_POLICY'] = nil
  end

  describe 'POST #create' do
    context 'with valid signature' do
      before do
        allow_any_instance_of(Webhooks::MuxController).to receive(:verify_signature!).and_return(true)
      end

      it 'updates episode on video.asset.ready' do
        post :create, body: payload
        expect(response).to have_http_status(:no_content)
        episode.reload
        expect(episode.mux_asset_id).to eq('new_asset_id')
        expect(episode.mux_playback_id).to eq('new_playback_id')
        expect(episode.video_status).to eq('ready')
      end

      it 'updates episode on video.asset.errored' do
        error_payload = { data: { passthrough: episode.id.to_s, id: 'error_asset_id' }, type: 'video.asset.errored' }.to_json
        error_signature = OpenSSL::HMAC.hexdigest('SHA256', secret, "\#{timestamp}.\#{error_payload}")
        request.headers['Mux-Signature'] = "t=\#{timestamp},v1=\#{error_signature}"
        
        post :create, body: error_payload
        expect(response).to have_http_status(:no_content)
        episode.reload
        expect(episode.mux_asset_id).to eq('error_asset_id')
        expect(episode.video_status).to eq('errored')
      end

      it 'returns no content if episode is not found' do
        not_found_payload = { data: { passthrough: '999999' }, type: 'video.asset.ready' }.to_json
        not_found_signature = OpenSSL::HMAC.hexdigest('SHA256', secret, "\#{timestamp}.\#{not_found_payload}")
        request.headers['Mux-Signature'] = "t=\#{timestamp},v1=\#{not_found_signature}"
        
        post :create, body: not_found_payload
        expect(response).to have_http_status(:no_content)
      end
    end

    context 'with invalid signature' do
      it 'returns bad request' do
        request.headers['Mux-Signature'] = "t=\#{timestamp},v1=invalid_signature"
        post :create, body: payload
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with missing timestamp or signature' do
      it 'returns bad request' do
        request.headers['Mux-Signature'] = nil
        post :create, body: payload
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with old timestamp' do
      let(:old_timestamp) { (Time.current - 10.minutes).to_i.to_s }
      it 'returns bad request' do
        old_signature = OpenSSL::HMAC.hexdigest('SHA256', secret, "\#{old_timestamp}.\#{payload}")
        request.headers['Mux-Signature'] = "t=\#{old_timestamp},v1=\#{old_signature}"
        post :create, body: payload
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
