# frozen_string_literal: true

FactoryBot.define do
  factory :group do
    sequence(:name) { |n| "テストグループ#{n}" }
    association :owner, factory: :user
    locale { 'ja' }

    trait :with_threshold do
      threshold_n { 3 }
      threshold_target { 'core' }
    end

    trait :with_times do
      default_start_time { '19:00' }
      default_end_time { '22:00' }
    end
  end
end
