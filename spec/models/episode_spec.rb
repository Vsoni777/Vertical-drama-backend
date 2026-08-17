require 'rails_helper'

RSpec.describe Episode, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:episode_number) }
    it { should validate_numericality_of(:coin_cost).is_greater_than_or_equal_to(0) }
    
    describe 'uniqueness' do
      subject { create(:episode) }
      it { should validate_uniqueness_of(:episode_number).scoped_to(:series_id) }
    end
  end

  describe 'associations' do
    it { should belong_to(:series) }
    it { should have_many(:episode_unlocks).dependent(:destroy) }
    it { should have_many(:watch_progresses).dependent(:destroy) }
  end

  describe 'enums' do
    it { should define_enum_for(:video_status).with_values(pending: 0, uploading: 1, processing: 2, ready: 3, errored: 4) }
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:episode)).to be_valid
    end
  end
end
