# frozen_string_literal: true

FactoryBot.define do
  factory :availability do
    association :user
    association :group
    date { Date.current }
    status { 1 }

    trait :ok do
      status { 1 }
    end

    trait :maybe do
      status { 0 }
      comment { '未定です' }
    end

    trait :ng do
      status { -1 }
      comment { '参加不可' }
    end

    trait :none do
      status { nil }
    end
  end
end
