# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:display_name) { |n| "テストユーザー#{n}" }
    locale { 'ja' }

    trait :with_discord do
      sequence(:discord_user_id) { |n| "discord_#{n}" }
      sequence(:discord_screen_name) { |n| "discord_screen_#{n}" }
    end

    trait :with_google do
      sequence(:google_account_id) { |n| "google_#{n}@example.com" }
      google_oauth_token { 'encrypted_token_value' }
      auth_locked { true }
    end

    trait :anonymized do
      sequence(:display_name) { |n| "退会済みメンバー#{n}" }
      anonymized { true }
      discord_user_id { nil }
      google_account_id { nil }
      google_oauth_token { nil }
    end
  end
end
