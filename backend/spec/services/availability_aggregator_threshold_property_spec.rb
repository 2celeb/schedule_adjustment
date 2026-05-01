# frozen_string_literal: true

require "rails_helper"
require "rantly"
require "rantly/property"

# Feature: schedule-management-tool, Property 9: 閾値判定
#
# 任意の threshold_n と threshold_target の設定について、
# ×人数が閾値以上で警告フラグが true、未満で false になることを検証する。
#
# Validates: 要件 4.7, 4.8
RSpec.describe "Property 9: 閾値判定" do
  # Rantly の property_of ヘルパー
  def property_of(&block)
    Rantly::Property.new(block)
  end

  let!(:owner) { create(:user) }
  let!(:group) { create(:group, owner: owner, threshold_n: 3, threshold_target: "core") }

  # 各イテレーションでグループに紐づくデータをクリーンアップする
  # FK 制約を考慮して availability_logs → availabilities → memberships の順で削除
  def cleanup_group_data!
    avail_ids = Availability.where(group: group).pluck(:id)
    AvailabilityLog.where(availability_id: avail_ids).delete_all if avail_ids.any?
    Availability.where(group: group).delete_all
    Membership.where(group: group).delete_all
  end

  describe "threshold_target='core' の場合、Core_Member の×人数で判定する" do
    it "任意の threshold_n と Core/Sub メンバー構成について、Core の×人数が閾値以上なら warning=true" do
      property_of {
        # threshold_n: 1〜10
        threshold_n = range(1, 10)
        # Core メンバー数: 1〜10
        core_count = range(1, 10)
        # Sub メンバー数: 0〜5
        sub_count = range(0, 5)
        # Core メンバーの status を生成（nil, 1, 0, -1）
        core_statuses = Array.new(core_count) { choose(nil, 1, 0, -1) }
        # Sub メンバーの status を生成
        sub_statuses = Array.new(sub_count) { choose(nil, 1, 0, -1) }
        [threshold_n, core_statuses, sub_statuses]
      }.check(100) do |threshold_n, core_statuses, sub_statuses|
        cleanup_group_data!

        # グループの閾値設定を更新
        group.update!(threshold_n: threshold_n, threshold_target: "core")

        target_date = Date.current + 1
        date_range = target_date..target_date

        # Core メンバーを作成し参加可否を設定
        core_statuses.each do |status|
          user = create(:user)
          create(:membership, user: user, group: group, role: "core")
          next if status.nil?
          create(:availability, user: user, group: group, date: target_date, status: status)
        end

        # Sub メンバーを作成し参加可否を設定
        sub_statuses.each do |status|
          user = create(:user)
          create(:membership, user: user, group: group, role: "sub")
          next if status.nil?
          create(:availability, user: user, group: group, date: target_date, status: status)
        end

        # 集計を実行
        aggregator = AvailabilityAggregator.new(group, date_range)
        result = aggregator.call
        entry = result[target_date.iso8601]

        # Core メンバーの×人数を手動で計算
        core_ng_count = core_statuses.count { |s| s == -1 }
        expected_warning = core_ng_count >= threshold_n

        expect(entry[:warning]).to eq(expected_warning),
          "閾値判定が不正: " \
          "threshold_n=#{threshold_n}, threshold_target=core, " \
          "core_ng=#{core_ng_count}, sub_statuses=#{sub_statuses.inspect}, " \
          "期待=#{expected_warning}, 実際=#{entry[:warning]}"
      end
    end

    it "Sub メンバーの×人数は threshold_target='core' の判定に影響しない" do
      property_of {
        # threshold_n を固定的に小さくして、Sub の×が影響しないことを確認
        threshold_n = range(1, 5)
        # Core メンバーは全員○（×なし）
        core_count = range(1, 5)
        # Sub メンバーは全員×
        sub_ng_count = range(1, 10)
        [threshold_n, core_count, sub_ng_count]
      }.check(100) do |threshold_n, core_count, sub_ng_count|
        cleanup_group_data!

        group.update!(threshold_n: threshold_n, threshold_target: "core")

        target_date = Date.current + 1
        date_range = target_date..target_date

        # Core メンバーは全員○
        core_count.times do
          user = create(:user)
          create(:membership, user: user, group: group, role: "core")
          create(:availability, user: user, group: group, date: target_date, status: 1)
        end

        # Sub メンバーは全員×
        sub_ng_count.times do
          user = create(:user)
          create(:membership, user: user, group: group, role: "sub")
          create(:availability, user: user, group: group, date: target_date, status: -1)
        end

        aggregator = AvailabilityAggregator.new(group, date_range)
        result = aggregator.call
        entry = result[target_date.iso8601]

        # Core の×は0人なので、threshold_n がいくつでも warning=false
        expect(entry[:warning]).to eq(false),
          "Sub の×が core 判定に影響している: " \
          "threshold_n=#{threshold_n}, core_ng=0, sub_ng=#{sub_ng_count}, " \
          "warning=#{entry[:warning]}"
      end
    end
  end

  describe "threshold_target='all' の場合、全メンバーの×人数で判定する" do
    it "任意の threshold_n と Core/Sub メンバー構成について、全メンバーの×人数が閾値以上なら warning=true" do
      property_of {
        threshold_n = range(1, 10)
        core_count = range(1, 8)
        sub_count = range(1, 8)
        core_statuses = Array.new(core_count) { choose(nil, 1, 0, -1) }
        sub_statuses = Array.new(sub_count) { choose(nil, 1, 0, -1) }
        [threshold_n, core_statuses, sub_statuses]
      }.check(100) do |threshold_n, core_statuses, sub_statuses|
        cleanup_group_data!

        group.update!(threshold_n: threshold_n, threshold_target: "all")

        target_date = Date.current + 1
        date_range = target_date..target_date

        core_statuses.each do |status|
          user = create(:user)
          create(:membership, user: user, group: group, role: "core")
          next if status.nil?
          create(:availability, user: user, group: group, date: target_date, status: status)
        end

        sub_statuses.each do |status|
          user = create(:user)
          create(:membership, user: user, group: group, role: "sub")
          next if status.nil?
          create(:availability, user: user, group: group, date: target_date, status: status)
        end

        aggregator = AvailabilityAggregator.new(group, date_range)
        result = aggregator.call
        entry = result[target_date.iso8601]

        # 全メンバーの×人数を手動で計算
        total_ng_count = core_statuses.count { |s| s == -1 } + sub_statuses.count { |s| s == -1 }
        expected_warning = total_ng_count >= threshold_n

        expect(entry[:warning]).to eq(expected_warning),
          "閾値判定が不正: " \
          "threshold_n=#{threshold_n}, threshold_target=all, " \
          "total_ng=#{total_ng_count} (core_ng=#{core_statuses.count { |s| s == -1 }}, sub_ng=#{sub_statuses.count { |s| s == -1 }}), " \
          "期待=#{expected_warning}, 実際=#{entry[:warning]}"
      end
    end

    it "threshold_target='all' では Sub メンバーの×も判定に含まれる" do
      property_of {
        # threshold_n を Sub の×だけで超えるケースを生成
        threshold_n = range(1, 5)
        # Core メンバーは全員○
        core_count = range(1, 5)
        # Sub メンバーの×人数を threshold_n 以上にする
        sub_ng_count = range(threshold_n, threshold_n + 5)
        [threshold_n, core_count, sub_ng_count]
      }.check(100) do |threshold_n, core_count, sub_ng_count|
        cleanup_group_data!

        group.update!(threshold_n: threshold_n, threshold_target: "all")

        target_date = Date.current + 1
        date_range = target_date..target_date

        # Core メンバーは全員○
        core_count.times do
          user = create(:user)
          create(:membership, user: user, group: group, role: "core")
          create(:availability, user: user, group: group, date: target_date, status: 1)
        end

        # Sub メンバーは全員×
        sub_ng_count.times do
          user = create(:user)
          create(:membership, user: user, group: group, role: "sub")
          create(:availability, user: user, group: group, date: target_date, status: -1)
        end

        aggregator = AvailabilityAggregator.new(group, date_range)
        result = aggregator.call
        entry = result[target_date.iso8601]

        # Sub の×だけで threshold_n 以上なので warning=true
        expect(entry[:warning]).to eq(true),
          "threshold_target=all で Sub の×が判定に含まれていない: " \
          "threshold_n=#{threshold_n}, core_ng=0, sub_ng=#{sub_ng_count}, " \
          "warning=#{entry[:warning]}"
      end
    end
  end

  describe "threshold_n が nil の場合" do
    it "任意のメンバー構成と参加可否について、warning は常に false" do
      property_of {
        member_count = range(1, 15)
        statuses = Array.new(member_count) { choose(nil, 1, 0, -1) }
        [member_count, statuses]
      }.check(100) do |member_count, statuses|
        cleanup_group_data!

        group.update!(threshold_n: nil, threshold_target: choose("core", "all"))

        target_date = Date.current + 1
        date_range = target_date..target_date

        statuses.each do |status|
          user = create(:user)
          role = choose("core", "sub")
          create(:membership, user: user, group: group, role: role)
          next if status.nil?
          create(:availability, user: user, group: group, date: target_date, status: status)
        end

        aggregator = AvailabilityAggregator.new(group, date_range)
        result = aggregator.call
        entry = result[target_date.iso8601]

        expect(entry[:warning]).to eq(false),
          "threshold_n=nil なのに warning=true: statuses=#{statuses.inspect}"
      end
    end
  end

  describe "境界値の検証" do
    it "×人数がちょうど threshold_n と等しい場合、warning=true になる" do
      property_of {
        threshold_n = range(1, 10)
        threshold_target = choose("core", "all")
        [threshold_n, threshold_target]
      }.check(100) do |threshold_n, threshold_target|
        cleanup_group_data!

        group.update!(threshold_n: threshold_n, threshold_target: threshold_target)

        target_date = Date.current + 1
        date_range = target_date..target_date

        # ちょうど threshold_n 人の×メンバーを作成
        # threshold_target に応じて Core または Sub で作成
        threshold_n.times do
          user = create(:user)
          role = threshold_target == "core" ? "core" : choose("core", "sub")
          create(:membership, user: user, group: group, role: role)
          create(:availability, user: user, group: group, date: target_date, status: -1)
        end

        # 追加で○のメンバーを数人作成
        extra_count = range(0, 5)
        extra_count.times do
          user = create(:user)
          create(:membership, user: user, group: group, role: "sub")
          create(:availability, user: user, group: group, date: target_date, status: 1)
        end

        aggregator = AvailabilityAggregator.new(group, date_range)
        result = aggregator.call
        entry = result[target_date.iso8601]

        expect(entry[:warning]).to eq(true),
          "×人数 == threshold_n なのに warning=false: " \
          "threshold_n=#{threshold_n}, threshold_target=#{threshold_target}"
      end
    end

    it "×人数が threshold_n - 1 の場合、warning=false になる" do
      property_of {
        # threshold_n >= 2 にして、threshold_n - 1 >= 1 を保証
        threshold_n = range(2, 10)
        threshold_target = choose("core", "all")
        [threshold_n, threshold_target]
      }.check(100) do |threshold_n, threshold_target|
        cleanup_group_data!

        group.update!(threshold_n: threshold_n, threshold_target: threshold_target)

        target_date = Date.current + 1
        date_range = target_date..target_date

        # threshold_n - 1 人の×メンバーを作成
        (threshold_n - 1).times do
          user = create(:user)
          role = threshold_target == "core" ? "core" : choose("core", "sub")
          create(:membership, user: user, group: group, role: role)
          create(:availability, user: user, group: group, date: target_date, status: -1)
        end

        # 追加で○のメンバーを数人作成
        extra_count = range(1, 5)
        extra_count.times do
          user = create(:user)
          create(:membership, user: user, group: group, role: "sub")
          create(:availability, user: user, group: group, date: target_date, status: 1)
        end

        aggregator = AvailabilityAggregator.new(group, date_range)
        result = aggregator.call
        entry = result[target_date.iso8601]

        expect(entry[:warning]).to eq(false),
          "×人数 == threshold_n - 1 なのに warning=true: " \
          "threshold_n=#{threshold_n}, ng_count=#{threshold_n - 1}, " \
          "threshold_target=#{threshold_target}"
      end
    end
  end

  describe "Owner は Core_Member として扱われる" do
    it "Owner の×は threshold_target='core' の判定に含まれる" do
      property_of {
        threshold_n = range(1, 5)
        extra_core = range(0, 4)
        [threshold_n, extra_core]
      }.check(100) do |threshold_n, extra_core|
        cleanup_group_data!

        group.update!(threshold_n: threshold_n, threshold_target: "core")

        target_date = Date.current + 1
        date_range = target_date..target_date

        # Owner をメンバーとして登録し×を設定（Owner は Core として扱われる）
        create(:membership, user: owner, group: group, role: "owner")
        create(:availability, user: owner, group: group, date: target_date, status: -1)

        # 追加の Core メンバーも×にする
        extra_core.times do
          user = create(:user)
          create(:membership, user: user, group: group, role: "core")
          create(:availability, user: user, group: group, date: target_date, status: -1)
        end

        aggregator = AvailabilityAggregator.new(group, date_range)
        result = aggregator.call
        entry = result[target_date.iso8601]

        # Owner + extra_core 人の Core メンバーが×
        total_core_ng = 1 + extra_core
        expected_warning = total_core_ng >= threshold_n

        expect(entry[:warning]).to eq(expected_warning),
          "Owner の×が core 判定に含まれていない: " \
          "threshold_n=#{threshold_n}, core_ng=#{total_core_ng}, " \
          "expected=#{expected_warning}, actual=#{entry[:warning]}"
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
