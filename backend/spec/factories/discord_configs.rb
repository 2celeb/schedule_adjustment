# frozen_string_literal: true

FactoryBot.define do
  factory :discord_config do
    association :group
    sequence(:guild_id) { |n| "guild_#{n}" }
    sequence(:default_channel_id) { |n| "channel_#{n}" }
  end
end
