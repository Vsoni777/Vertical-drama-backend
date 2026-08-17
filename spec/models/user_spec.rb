require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_presence_of(:password).on(:create) }
  end

  describe 'associations' do
    it { should have_many(:subscriptions).dependent(:destroy) }
    it { should have_many(:coin_transactions).dependent(:destroy) }
    it { should have_many(:episode_unlocks).dependent(:destroy) }
    it { should have_many(:watch_progresses).dependent(:destroy) }
    it { should have_many(:unlocked_episodes).through(:episode_unlocks).source(:episode) }
  end

  describe 'enums' do
    it { should define_enum_for(:role).with_values([:viewer, :admin]) }
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:user)).to be_valid
    end
  end
end
