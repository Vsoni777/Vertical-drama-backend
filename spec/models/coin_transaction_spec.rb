require 'rails_helper'

RSpec.describe CoinTransaction, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:amount) }
    it { should validate_numericality_of(:amount) }
  end

  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'enums' do
    it { should define_enum_for(:transaction_type).with_values(purchase: 0, unlock: 1, reward: 2, refund: 3) }
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:coin_transaction)).to be_valid
    end
  end
end
