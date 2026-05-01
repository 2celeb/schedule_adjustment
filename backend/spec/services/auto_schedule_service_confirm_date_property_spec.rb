# frozen_string_literal: true

require "rails_helper"
require "rantly"
require "rantly/property"

# Feature: schedule-management-tool, Property 12: 確定日計算
#
# 任意の week_start_day（0〜6）と confirm_days_before（正の整数）について、
# 計算された確定日は week_start_day の confirm_days_before 日前の日付と一致しなければならない。
#
# Validates: 要件 5.4
RSpec.describe "Property 12: 確定日計算" do
  # Rantly の property_of ヘルパー
  def property_of(&block)
    Rantly::Property.new(block)
  end

  let!(:owner) { create(:user) }
  let!(:group) { create(:group, :with_times, owner: owner) }

  # 各イテレーションでルールをクリーンアップする
  def cleanup_rule!
    AutoScheduleRule.where(group: group).delete_all
  end

  # テスト用の基準日（2026-05-04 は月曜日）
  let(:base_date) { Date.new(2026, 5, 4) }

  describe "confirm_date_for の計算" do
    it "任意の week_start_day と confirm_days_before について、確定日が week_start_day の confirm_days_before 日前と一致する" do
      property_of {
        week_start_day = range(0, 6)
        confirm_days_before = range(1, 14)
        # 基準日をランダムにずらして多様な日付パターンをテスト
        date_offset = range(0, 30)
        [week_start_day, confirm_days_before, date_offset]
      }.check(100) do |week_start_day, confirm_days_before, date_offset|
        cleanup_rule!

        create(:auto_schedule_rule,
          group: group,
          week_start_day: week_start_day,
          confirm_days_before: confirm_days_before,
          max_days_per_week: 3,
          min_days_per_week: 1,
          excluded_days: [],
          deprioritized_days: []
        )

        target_date = base_date + date_offset.days
        group.reload
        service = AutoScheduleService.new(group)

        # 確定日を計算
        confirm_date = service.confirm_date_for(target_date)

        # next_week_start を使って期待値を独立に計算
        # next_week_start は target_date 以降で最初の week_start_day の曜日を返す
        expected_week_start = target_date
        expected_week_start += 1.day until expected_week_start.wday == week_start_day
        expected_confirm_date = expected_week_start - confirm_days_before.days

        expect(confirm_date).to eq(expected_confirm_date),
          "確定日計算が不正: " \
          "week_start_day=#{week_start_day}, confirm_days_before=#{confirm_days_before}, " \
          "target_date=#{target_date}(#{target_date.strftime('%A')}), " \
          "expected_week_start=#{expected_week_start}(#{expected_week_start.strftime('%A')}), " \
          "expected=#{expected_confirm_date}, actual=#{confirm_date}"
      end
    end
  end

  describe "確定日と週開始日の関係" do
    it "確定日は常に週開始日より前の日付である" do
      property_of {
        week_start_day = range(0, 6)
        confirm_days_before = range(1, 14)
        date_offset = range(0, 30)
        [week_start_day, confirm_days_before, date_offset]
      }.check(100) do |week_start_day, confirm_days_before, date_offset|
        cleanup_rule!

        create(:auto_schedule_rule,
          group: group,
          week_start_day: week_start_day,
          confirm_days_before: confirm_days_before,
          max_days_per_week: 3,
          min_days_per_week: 1,
          excluded_days: [],
          deprioritized_days: []
        )

        target_date = base_date + date_offset.days
        group.reload
        service = AutoScheduleService.new(group)

        confirm_date = service.confirm_date_for(target_date)
        week_start = service.next_week_start(target_date)

        expect(confirm_date).to be < week_start,
          "確定日が週開始日以降になっている: " \
          "confirm_date=#{confirm_date}, week_start=#{week_start}, " \
          "week_start_day=#{week_start_day}, confirm_days_before=#{confirm_days_before}"
      end
    end
  end

  describe "確定日と週開始日の差分" do
    it "週開始日と確定日の差が confirm_days_before と一致する" do
      property_of {
        week_start_day = range(0, 6)
        confirm_days_before = range(1, 14)
        date_offset = range(0, 30)
        [week_start_day, confirm_days_before, date_offset]
      }.check(100) do |week_start_day, confirm_days_before, date_offset|
        cleanup_rule!

        create(:auto_schedule_rule,
          group: group,
          week_start_day: week_start_day,
          confirm_days_before: confirm_days_before,
          max_days_per_week: 3,
          min_days_per_week: 1,
          excluded_days: [],
          deprioritized_days: []
        )

        target_date = base_date + date_offset.days
        group.reload
        service = AutoScheduleService.new(group)

        confirm_date = service.confirm_date_for(target_date)
        week_start = service.next_week_start(target_date)

        actual_diff = (week_start - confirm_date).to_i

        expect(actual_diff).to eq(confirm_days_before),
          "週開始日と確定日の差分が不正: " \
          "expected_diff=#{confirm_days_before}, actual_diff=#{actual_diff}, " \
          "confirm_date=#{confirm_date}, week_start=#{week_start}, " \
          "week_start_day=#{week_start_day}, target_date=#{target_date}"
      end
    end
  end

  describe "next_week_start の曜日一致" do
    it "next_week_start が返す日付の曜日は week_start_day と一致する" do
      property_of {
        week_start_day = range(0, 6)
        date_offset = range(0, 60)
        [week_start_day, date_offset]
      }.check(100) do |week_start_day, date_offset|
        cleanup_rule!

        create(:auto_schedule_rule,
          group: group,
          week_start_day: week_start_day,
          confirm_days_before: 3,
          max_days_per_week: 3,
          min_days_per_week: 1,
          excluded_days: [],
          deprioritized_days: []
        )

        target_date = base_date + date_offset.days
        group.reload
        service = AutoScheduleService.new(group)

        week_start = service.next_week_start(target_date)

        expect(week_start.wday).to eq(week_start_day),
          "next_week_start の曜日が不正: " \
          "expected_wday=#{week_start_day}, actual_wday=#{week_start.wday}, " \
          "target_date=#{target_date}(#{target_date.strftime('%A')}), " \
          "week_start=#{week_start}(#{week_start.strftime('%A')})"

        # next_week_start は target_date 以降であること
        expect(week_start).to be >= target_date,
          "next_week_start が target_date より前: " \
          "week_start=#{week_start}, target_date=#{target_date}"

        # next_week_start は target_date から最大6日後以内であること
        expect((week_start - target_date).to_i).to be <= 6,
          "next_week_start が target_date から7日以上先: " \
          "week_start=#{week_start}, target_date=#{target_date}, " \
          "diff=#{(week_start - target_date).to_i}"
      end
    end
  end
end
