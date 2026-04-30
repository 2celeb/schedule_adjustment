# frozen_string_literal: true

FactoryBot.define do
  factory :membership do
    association :user
    association :group
    role { 'sub' }

    trait :owner do
      role { 'owner' }
    end

    trait :core do
      role { 'core' }
    end
  end
end
