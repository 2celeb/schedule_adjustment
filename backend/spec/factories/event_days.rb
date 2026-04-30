# frozen_string_literal: true

FactoryBot.define do
  factory :event_day do
    association :group
    date { Date.current }

    trait :confirmed do
      confirmed { true }
      confirmed_at { Time.current }
    end

    trait :with_times do
      start_time { '19:00' }
      end_time { '22:00' }
    end
  end
end
