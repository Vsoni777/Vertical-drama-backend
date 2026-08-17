FactoryBot.define do
  factory :user do
    email { Faker::Internet.unique.email }
    password { 'password123' }
    role { :viewer }
    coin_balance { 100 }
    stripe_customer_id { "cus_#{Faker::Alphanumeric.alphanumeric(number: 14)}" }

    trait :admin do
      role { :admin }
    end
  end

  factory :series do
    title { Faker::Movie.title }
    description { Faker::Lorem.paragraph }
    genre { 'Drama' }
    status { :ongoing }
    is_published { true }
    release_date { Time.current }
  end

  factory :episode do
    association :series
    title { Faker::Movie.title }
    description { Faker::Lorem.paragraph }
    sequence(:episode_number) { |n| n }
    duration { 120 }
    coin_cost { 10 }
    locked { true }
    video_status { :ready }
    mux_asset_id { "asset_#{Faker::Alphanumeric.alphanumeric(number: 10)}" }
    mux_playback_id { "playback_#{Faker::Alphanumeric.alphanumeric(number: 10)}" }
  end

  factory :coin_transaction do
    association :user
    amount { 10 }
    transaction_type { :purchase }
    description { 'Purchased coins' }
  end

  factory :episode_unlock do
    association :user
    association :episode
  end

  factory :subscription do
    association :user
    plan { 'monthly' }
    status { :active }
    started_at { Time.current }
    ends_at { 1.month.from_now }
    stripe_price_id { "price_#{Faker::Alphanumeric.alphanumeric(number: 14)}" }
    stripe_subscription_id { "sub_#{Faker::Alphanumeric.alphanumeric(number: 14)}" }
  end

  factory :watch_progress do
    association :user
    association :episode
    association :series
    progress_seconds { 30 }
    completed { false }
  end
end
