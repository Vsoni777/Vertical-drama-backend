require 'rails_helper'

RSpec.describe Subscription, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:plan) }
  end

  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(active: 0, cancelled: 1, expired: 2) }
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:subscription)).to be_valid
    end
  end
end
