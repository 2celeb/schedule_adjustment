# frozen_string_literal: true

FactoryBot.define do
  factory :auto_schedule_rule do
    association :group
    week_start_day { 1 }
    confirm_days_before { 3 }

    trait :with_limits do
      max_days_per_week { 3 }
      min_days_per_week { 1 }
    end
  end
end
