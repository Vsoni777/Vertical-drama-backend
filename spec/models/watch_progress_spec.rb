require 'rails_helper'

RSpec.describe WatchProgress, type: :model do
  describe 'validations' do
    it { should validate_numericality_of(:progress_seconds).is_greater_than_or_equal_to(0) }

    describe 'uniqueness' do
      subject { create(:watch_progress) }
      it { should validate_uniqueness_of(:user_id).scoped_to(:episode_id) }
    end
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:episode) }
    it { should belong_to(:series) }
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:watch_progress)).to be_valid
    end
  end
end
