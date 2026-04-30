# frozen_string_literal: true

FactoryBot.define do
  factory :availability_log do
    association :availability
    association :user
    old_status { nil }
    new_status { 1 }
  end
end
