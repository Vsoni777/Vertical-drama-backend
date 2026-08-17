require 'rails_helper'

RSpec.describe EpisodeUnlock, type: :model do
  describe 'validations' do
    describe 'uniqueness' do
      subject { create(:episode_unlock) }
      it { should validate_uniqueness_of(:user_id).scoped_to(:episode_id).with_message("already unlocked this episode") }
    end
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:episode) }
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:episode_unlock)).to be_valid
    end
  end
end
