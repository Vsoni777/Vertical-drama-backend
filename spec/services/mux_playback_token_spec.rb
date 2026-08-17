require 'rails_helper'

RSpec.describe MuxPlaybackToken do
  describe '.generate' do
    let(:playback_id) { 'test_playback_id' }
    let(:signing_key) { 'test_signing_key' }
    let(:private_key) { OpenSSL::PKey::RSA.new(2048).to_pem }

    before do
      allow(Rails.application).to receive(:credentials).and_return(double(dig: nil))
      ENV['MUX_SIGNING_KEY'] = signing_key
      ENV['MUX_PRIVATE_KEY'] = Base64.encode64(private_key)
    end

    after do
      ENV['MUX_SIGNING_KEY'] = nil
      ENV['MUX_PRIVATE_KEY'] = nil
    end

    it 'generates a valid JWT token' do
      token = described_class.generate(playback_id)
      expect(token).to be_a(String)
      parts = token.split('.')
      expect(parts.size).to eq(3)
    end

    context 'when configuration is missing' do
      it 'raises ConfigurationError if MUX_SIGNING_KEY is missing' do
        ENV['MUX_SIGNING_KEY'] = nil
        expect {
          described_class.generate(playback_id)
        }.to raise_error(MuxPlaybackToken::ConfigurationError, /MUX_SIGNING_KEY is not configured/)
      end

      it 'raises ConfigurationError if MUX_PRIVATE_KEY is missing' do
        ENV['MUX_PRIVATE_KEY'] = nil
        expect {
          described_class.generate(playback_id)
        }.to raise_error(MuxPlaybackToken::ConfigurationError, /MUX_PRIVATE_KEY is not configured/)
      end
    end
  end
end
