# frozen_string_literal: true

FactoryBot.define do
  factory :session do
    association :user
    token { SecureRandom.hex(32) }
    expires_at { 30.days.from_now }

    trait :expired do
      expires_at { 1.hour.ago }
    end
  end
end
