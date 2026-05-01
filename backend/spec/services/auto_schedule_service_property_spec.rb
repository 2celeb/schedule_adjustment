# frozen_string_literal: true

require "rails_helper"
require "rantly"
require "rantly/property"

# Feature: schedule-management-tool, Property 11: 自動スケジュールルールの制約充足
#
# 任意のルール（最大/最低活動日数、除外曜日、優先度を下げる曜日）と
# 参加可否データについて、自動生成された Event_Day の集合は以下を満たす:
# - 週あたりの活動日数が max_days_per_week 以下
# - 週あたりの活動日数が min_days_per_week 以上
# - excluded_days に含まれる曜日は、min_days_per_week 未達の場合を除き活動日にならない
#
# Validates: 要件 5.1
RSpec.describe "Property 11: 自動スケジュールルールの制約充足" do
  # Rantly の property_of ヘルパー
  def property_of(&block)
    Rantly::Property.new(block)
  end

  let!(:owner) { create(:user) }
  let!(:group) { create(:group, :with_times, owner: owner) }

  # 各イテレーションでグループに紐づくデータをクリーンアップする
  def cleanup_group_data!
    EventDay.where(group: group).delete_all
    avail_ids = Availability.where(group: group).pluck(:id)
    AvailabilityLog.where(availability_id: avail_ids).delete_all if avail_ids.any?
    Availability.where(group: group).delete_all
    Membership.where(group: group).delete_all
    AutoScheduleRule.where(group: group).delete_all
  end

  # 2026-05-04 は月曜日。テスト用の固定基準日として使用
  let(:base_monday) { Date.new(2026, 5, 4) }

  describe "max_days_per_week 制約" do
    it "任意のルールと参加可否データについて、生成される活動日数が max_days_per_week 以下である" do
      property_of {
        max_days = range(1, 7)
        min_days = range(0, max_days)
        week_start_day = range(0, 6)
        member_count = range(1, 10)
        # 各メンバーの7日分の status を生成（nil, 1, 0, -1）
        member_statuses = Array.new(member_count) {
          Array.new(7) { choose(nil, 1, 0, -1) }
        }
        [max_days, min_days, week_start_day, member_statuses]
      }.check(100) do |max_days, min_days, week_start_day, member_statuses|
        cleanup_group_data!

        rule = create(:auto_schedule_rule,
          group: group,
          max_days_per_week: max_days,
          min_days_per_week: min_days,
          week_start_day: week_start_day,
          excluded_days: [],
          deprioritized_days: []
        )

        # week_start_day に対応する基準日を計算
        start_date = base_monday
        start_date += 1.day until start_date.wday == week_start_day

        # メンバーと参加可否データを作成
        member_statuses.each do |statuses|
          user = create(:user)
          create(:membership, user: user, group: group, role: "core")
          statuses.each_with_index do |status, i|
            next if status.nil?
            create(:availability, user: user, group: group, date: start_date + i, status: status)
          end
        end

        # 活動日を生成
        group.reload
        service = AutoScheduleService.new(group)
        result = service.generate_for_week(start_date)

        expect(result.size).to be <= max_days,
          "max_days_per_week 制約違反: " \
          "max=#{max_days}, 生成数=#{result.size}, " \
          "week_start_day=#{week_start_day}, メンバー数=#{member_statuses.size}"
      end
    end
  end

  describe "min_days_per_week 制約" do
    it "任意のルールと参加可否データについて、生成される活動日数が min_days_per_week 以上である" do
      property_of {
        max_days = range(1, 7)
        min_days = range(0, max_days)
        week_start_day = range(0, 6)
        member_count = range(1, 10)
        member_statuses = Array.new(member_count) {
          Array.new(7) { choose(nil, 1, 0, -1) }
        }
        [max_days, min_days, week_start_day, member_statuses]
      }.check(100) do |max_days, min_days, week_start_day, member_statuses|
        cleanup_group_data!

        rule = create(:auto_schedule_rule,
          group: group,
          max_days_per_week: max_days,
          min_days_per_week: min_days,
          week_start_day: week_start_day,
          excluded_days: [],
          deprioritized_days: []
        )

        start_date = base_monday
        start_date += 1.day until start_date.wday == week_start_day

        member_statuses.each do |statuses|
          user = create(:user)
          create(:membership, user: user, group: group, role: "core")
          statuses.each_with_index do |status, i|
            next if status.nil?
            create(:availability, user: user, group: group, date: start_date + i, status: status)
          end
        end

        group.reload
        service = AutoScheduleService.new(group)
        result = service.generate_for_week(start_date)

        expect(result.size).to be >= min_days,
          "min_days_per_week 制約違反: " \
          "min=#{min_days}, max=#{max_days}, 生成数=#{result.size}, " \
          "week_start_day=#{week_start_day}, メンバー数=#{member_statuses.size}"
      end
    end
  end

  describe "excluded_days 制約" do
    it "min 充足時、excluded_days に含まれる曜日は活動日にならない" do
      property_of {
        # excluded_days を 0〜3 個ランダムに選択（最大3個に制限して min 充足しやすくする）
        all_wdays = (0..6).to_a
        excluded_count = range(0, 3)
        excluded_days = all_wdays.sample(excluded_count).sort
        non_excluded_count = 7 - excluded_count
        # max は non_excluded_count 以下にして、excluded なしで min を満たせるようにする
        max_days = range(1, [non_excluded_count, 7].min)
        # min は max 以下かつ non_excluded_count 以下にする
        min_days = range(0, [max_days, non_excluded_count].min)
        week_start_day = range(0, 6)
        member_count = range(1, 8)
        member_statuses = Array.new(member_count) {
          Array.new(7) { choose(nil, 1, 0, -1) }
        }
        [max_days, min_days, week_start_day, excluded_days, member_statuses]
      }.check(100) do |max_days, min_days, week_start_day, excluded_days, member_statuses|
        cleanup_group_data!

        rule = create(:auto_schedule_rule,
          group: group,
          max_days_per_week: max_days,
          min_days_per_week: min_days,
          week_start_day: week_start_day,
          excluded_days: excluded_days,
          deprioritized_days: []
        )

        start_date = base_monday
        start_date += 1.day until start_date.wday == week_start_day

        member_statuses.each do |statuses|
          user = create(:user)
          create(:membership, user: user, group: group, role: "core")
          statuses.each_with_index do |status, i|
            next if status.nil?
            create(:availability, user: user, group: group, date: start_date + i, status: status)
          end
        end

        group.reload
        service = AutoScheduleService.new(group)
        result = service.generate_for_week(start_date)
        result_wdays = result.map { |ed| ed.date.wday }

        # min が充足されている場合、excluded_days の曜日は含まれないはず
        non_excluded_count = result.count { |ed| !excluded_days.include?(ed.date.wday) }
        if non_excluded_count >= min_days
          excluded_in_result = result_wdays.select { |w| excluded_days.include?(w) }
          expect(excluded_in_result).to be_empty,
            "min 充足時に excluded_days が活動日に含まれている: " \
            "excluded_days=#{excluded_days}, 結果の曜日=#{result_wdays}, " \
            "excluded_in_result=#{excluded_in_result}, " \
            "min=#{min_days}, max=#{max_days}, 生成数=#{result.size}"
        end
      end
    end

    it "min 未達の場合は excluded_days の曜日も活動日になりうる" do
      property_of {
        # 除外曜日を多めに設定して min 未達を発生させやすくする
        all_wdays = (0..6).to_a
        excluded_count = range(4, 6)
        excluded_days = all_wdays.sample(excluded_count).sort
        non_excluded_count = 7 - excluded_count
        # min を non_excluded_count より大きくして、excluded なしでは min を満たせない状況を作る
        min_days = range([non_excluded_count + 1, 1].max, [non_excluded_count + 3, 7].min)
        max_days = range(min_days, 7)
        week_start_day = range(0, 6)
        member_count = range(1, 5)
        # 全メンバー全日○にして、スコアで除外されないようにする
        member_statuses = Array.new(member_count) {
          Array.new(7) { 1 }
        }
        [max_days, min_days, week_start_day, excluded_days, member_statuses]
      }.check(100) do |max_days, min_days, week_start_day, excluded_days, member_statuses|
        cleanup_group_data!

        rule = create(:auto_schedule_rule,
          group: group,
          max_days_per_week: max_days,
          min_days_per_week: min_days,
          week_start_day: week_start_day,
          excluded_days: excluded_days,
          deprioritized_days: []
        )

        start_date = base_monday
        start_date += 1.day until start_date.wday == week_start_day

        member_statuses.each do |statuses|
          user = create(:user)
          create(:membership, user: user, group: group, role: "core")
          statuses.each_with_index do |status, i|
            next if status.nil?
            create(:availability, user: user, group: group, date: start_date + i, status: status)
          end
        end

        group.reload
        service = AutoScheduleService.new(group)
        result = service.generate_for_week(start_date)

        # min_days_per_week 以上の活動日が生成されること（excluded を含めて）
        expect(result.size).to be >= min_days,
          "min 未達時に excluded を含めても min を満たせていない: " \
          "excluded_days=#{excluded_days}, min=#{min_days}, max=#{max_days}, " \
          "生成数=#{result.size}"
      end
    end
  end

  describe "max/min/excluded の複合制約" do
    it "任意のルール設定で全制約が同時に満たされる" do
      property_of {
        all_wdays = (0..6).to_a
        excluded_count = range(0, 4)
        excluded_days = all_wdays.sample(excluded_count).sort
        deprioritized_candidates = all_wdays - excluded_days
        depri_count = range(0, [deprioritized_candidates.size, 3].min)
        deprioritized_days = deprioritized_candidates.sample(depri_count).sort
        max_days = range(1, 7)
        min_days = range(0, max_days)
        week_start_day = range(0, 6)
        member_count = range(1, 8)
        member_statuses = Array.new(member_count) {
          Array.new(7) { choose(nil, 1, 0, -1) }
        }
        [max_days, min_days, week_start_day, excluded_days, deprioritized_days, member_statuses]
      }.check(100) do |max_days, min_days, week_start_day, excluded_days, deprioritized_days, member_statuses|
        cleanup_group_data!

        rule = create(:auto_schedule_rule,
          group: group,
          max_days_per_week: max_days,
          min_days_per_week: min_days,
          week_start_day: week_start_day,
          excluded_days: excluded_days,
          deprioritized_days: deprioritized_days
        )

        start_date = base_monday
        start_date += 1.day until start_date.wday == week_start_day

        member_statuses.each do |statuses|
          user = create(:user)
          create(:membership, user: user, group: group, role: "core")
          statuses.each_with_index do |status, i|
            next if status.nil?
            create(:availability, user: user, group: group, date: start_date + i, status: status)
          end
        end

        group.reload
        service = AutoScheduleService.new(group)
        result = service.generate_for_week(start_date)
        result_dates = result.map(&:date)
        result_wdays = result_dates.map(&:wday)

        # 制約1: max_days_per_week 以下
        expect(result.size).to be <= max_days,
          "max 制約違反: max=#{max_days}, 生成数=#{result.size}"

        # 制約2: min_days_per_week 以上
        expect(result.size).to be >= min_days,
          "min 制約違反: min=#{min_days}, 生成数=#{result.size}"

        # 制約3: excluded_days は min 充足時に含まれない
        non_excluded_in_result = result.count { |ed| !excluded_days.include?(ed.date.wday) }
        if non_excluded_in_result >= min_days
          excluded_in_result = result_wdays.select { |w| excluded_days.include?(w) }
          expect(excluded_in_result).to be_empty,
            "min 充足時に excluded が含まれている: " \
            "excluded_days=#{excluded_days}, deprioritized_days=#{deprioritized_days}, " \
            "結果の曜日=#{result_wdays}, min=#{min_days}, max=#{max_days}"
        end

        # 制約4: 全ての活動日が対象週の7日間に含まれる
        week_dates = (0..6).map { |i| start_date + i }
        result_dates.each do |d|
          expect(week_dates).to include(d),
            "対象週外の日付が含まれている: #{d} (週: #{week_dates.first}〜#{week_dates.last})"
        end

        # 制約5: 活動日に重複がない
        expect(result_dates.uniq.size).to eq(result_dates.size),
          "活動日に重複がある: #{result_dates}"
      end
    end
  end

  private

  # Rantly の choose をテストコンテキストで使用するためのヘルパー
  def choose(*options)
    options.sample
  end

  # Rantly の range をテストコンテキストで使用するためのヘルパー
  def range(min, max)
    rand(min..max)
  end
end
