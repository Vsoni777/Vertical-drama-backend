require 'rails_helper'

RSpec.describe MuxVideo do
  describe '.create_direct_upload!' do
    let(:episode_id) { 1 }
    let(:cors_origin) { 'http://localhost:3000' }
    let(:mux_response) do
      {
        'data' => {
          'id' => 'upload_id_123',
          'url' => 'https://storage.googleapis.com/mux-upload/upload_id_123'
        }
      }
    end

    before do
      ENV['MUX_TOKEN_ID'] = 'test_token_id'
      ENV['MUX_TOKEN_SECRET'] = 'test_token_secret'
      stub_request(:post, "https://api.mux.com/video/v1/uploads").
        to_return(status: 200, body: mux_response.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    after do
      ENV['MUX_TOKEN_ID'] = nil
      ENV['MUX_TOKEN_SECRET'] = nil
    end

    it 'creates a direct upload and returns data' do
      result = described_class.create_direct_upload!(episode_id: episode_id, cors_origin: cors_origin)
      expect(result).to eq(mux_response['data'])
    end

    context 'when credentials are missing' do
      it 'raises an Error if MUX_TOKEN_ID is missing' do
        ENV['MUX_TOKEN_ID'] = nil
        expect {
          described_class.create_direct_upload!(episode_id: episode_id, cors_origin: cors_origin)
        }.to raise_error(MuxVideo::Error, /MUX_TOKEN_ID and MUX_TOKEN_SECRET must be configured/)
      end
    end
  end
end
