# frozen_string_literal: true

FactoryBot.define do
  factory :calendar_cache do
    association :user
    association :group
    date { Date.current }
    has_event { false }
    fetched_at { Time.current }

    trait :stale do
      fetched_at { 20.minutes.ago }
    end

    trait :fresh do
      fetched_at { 5.minutes.ago }
    end

    trait :with_event do
      has_event { true }
    end
  end
end
