# frozen_string_literal: true

require "rails_helper"
require "rantly"
require "rantly/property"

# Feature: schedule-management-tool, Property 8: 集計の正確性（不変条件）
#
# 任意の日付とメンバー集合について、ok + maybe + ng + none の合計が
# グループ総メンバー数と一致することを検証する。
#
# Validates: 要件 4.4
RSpec.describe "Property 8: 集計の正確性（不変条件）" do
  # Rantly の property_of ヘルパー
  def property_of(&block)
    Rantly::Property.new(block)
  end

  let!(:owner) { create(:user) }
  let!(:group) { create(:group, owner: owner, threshold_n: nil, threshold_target: "core") }

  # 各イテレーションでグループに紐づくデータをクリーンアップする
  # FK 制約を考慮して availability_logs → availabilities → memberships の順で削除
  def cleanup_group_data!
    avail_ids = Availability.where(group: group).pluck(:id)
    AvailabilityLog.where(availability_id: avail_ids).delete_all if avail_ids.any?
    Availability.where(group: group).delete_all
    Membership.where(group: group).delete_all
  end

  describe "ok + maybe + ng + none == 総メンバー数" do
    it "任意のメンバー数と参加可否の組み合わせで、集計合計が総メンバー数と一致する" do
      property_of {
        # メンバー数: 1〜20（グループ上限）
        member_count = range(1, 20)
        # 日付範囲の長さ: 1〜14日
        date_range_length = range(1, 14)
        # 各メンバーの各日付に対する status を生成
        # nil = 未入力、1 = ○、0 = △、-1 = ×
        statuses = Array.new(member_count) do
          Array.new(date_range_length) do
            choose(nil, 1, 0, -1)
          end
        end
        [member_count, date_range_length, statuses]
      }.check(100) do |member_count, date_range_length, statuses|
        cleanup_group_data!

        # メンバーを作成
        members = Array.new(member_count) do
          user = create(:user)
          role = choose("core", "sub")
          create(:membership, user: user, group: group, role: role)
          user
        end

        # 日付範囲を設定（未来の日付を使用）
        start_date = Date.current + 1
        end_date = start_date + (date_range_length - 1)
        date_range = start_date..end_date

        # 参加可否データを作成
        members.each_with_index do |user, member_idx|
          date_range.each_with_index do |date, date_idx|
            status = statuses[member_idx][date_idx]
            next if status.nil? # nil は未入力（レコードなし）

            create(:availability,
                   user: user,
                   group: group,
                   date: date,
                   status: status)
          end
        end

        # 集計を実行
        aggregator = AvailabilityAggregator.new(group, date_range)
        result = aggregator.call

        # 全日付について ok + maybe + ng + none == 総メンバー数 を検証
        date_range.each do |date|
          entry = result[date.iso8601]
          expect(entry).to be_present,
            "集計結果に日付 #{date.iso8601} が存在しない"

          total = entry[:ok] + entry[:maybe] + entry[:ng] + entry[:none]
          expect(total).to eq(member_count),
            "集計合計が総メンバー数と不一致: " \
            "ok=#{entry[:ok]}, maybe=#{entry[:maybe]}, ng=#{entry[:ng]}, none=#{entry[:none]}, " \
            "合計=#{total}, 期待=#{member_count}, 日付=#{date.iso8601}"
        end
      end
    end

    it "メンバーが0人の場合、全カウントが0になる" do
      # メンバーなしの状態で集計
      date_range = Date.current..(Date.current + 6)
      aggregator = AvailabilityAggregator.new(group, date_range)
      result = aggregator.call

      date_range.each do |date|
        entry = result[date.iso8601]
        total = entry[:ok] + entry[:maybe] + entry[:ng] + entry[:none]
        expect(total).to eq(0),
          "メンバー0人なのに集計合計が0でない: 合計=#{total}, 日付=#{date.iso8601}"
      end
    end

    it "全メンバーが未入力の場合、none が総メンバー数と一致する" do
      property_of {
        range(1, 20)
      }.check(100) do |member_count|
        cleanup_group_data!

        member_count.times do
          user = create(:user)
          create(:membership, user: user, group: group)
        end

        date_range = Date.current..(Date.current + 6)
        aggregator = AvailabilityAggregator.new(group, date_range)
        result = aggregator.call

        date_range.each do |date|
          entry = result[date.iso8601]
          expect(entry[:ok]).to eq(0),
            "未入力のみなのに ok が0でない: ok=#{entry[:ok]}"
          expect(entry[:maybe]).to eq(0),
            "未入力のみなのに maybe が0でない: maybe=#{entry[:maybe]}"
          expect(entry[:ng]).to eq(0),
            "未入力のみなのに ng が0でない: ng=#{entry[:ng]}"
          expect(entry[:none]).to eq(member_count),
            "none が総メンバー数と不一致: none=#{entry[:none]}, 期待=#{member_count}"
        end
      end
    end

    it "全メンバーが入力済みの場合、none が0になる" do
      property_of {
        member_count = range(1, 15)
        # 全メンバーに有効な status を割り当て（nil なし）
        statuses = Array.new(member_count) { choose(1, 0, -1) }
        [member_count, statuses]
      }.check(100) do |member_count, statuses|
        cleanup_group_data!

        target_date = Date.current + 1
        date_range = target_date..target_date

        members = Array.new(member_count) do
          user = create(:user)
          create(:membership, user: user, group: group)
          user
        end

        members.each_with_index do |user, idx|
          create(:availability,
                 user: user,
                 group: group,
                 date: target_date,
                 status: statuses[idx])
        end

        aggregator = AvailabilityAggregator.new(group, date_range)
        result = aggregator.call
        entry = result[target_date.iso8601]

        expect(entry[:none]).to eq(0),
          "全メンバー入力済みなのに none が0でない: none=#{entry[:none]}"

        total = entry[:ok] + entry[:maybe] + entry[:ng] + entry[:none]
        expect(total).to eq(member_count),
          "集計合計が総メンバー数と不一致: 合計=#{total}, 期待=#{member_count}"
      end
    end

    it "各カウントが非負であること" do
      property_of {
        member_count = range(1, 15)
        statuses = Array.new(member_count) { choose(nil, 1, 0, -1) }
        [member_count, statuses]
      }.check(100) do |member_count, statuses|
        cleanup_group_data!

        target_date = Date.current + 1
        date_range = target_date..target_date

        members = Array.new(member_count) do
          user = create(:user)
          create(:membership, user: user, group: group)
          user
        end

        members.each_with_index do |user, idx|
          next if statuses[idx].nil?
          create(:availability,
                 user: user,
                 group: group,
                 date: target_date,
                 status: statuses[idx])
        end

        aggregator = AvailabilityAggregator.new(group, date_range)
        result = aggregator.call
        entry = result[target_date.iso8601]

        expect(entry[:ok]).to be >= 0, "ok が負: #{entry[:ok]}"
        expect(entry[:maybe]).to be >= 0, "maybe が負: #{entry[:maybe]}"
        expect(entry[:ng]).to be >= 0, "ng が負: #{entry[:ng]}"
        expect(entry[:none]).to be >= 0, "none が負: #{entry[:none]}"
      end
    end
  end

  private

  # Rantly の choose をテストコンテキストで使用するためのヘルパー
  def choose(*options)
    options.sample
  end
end
