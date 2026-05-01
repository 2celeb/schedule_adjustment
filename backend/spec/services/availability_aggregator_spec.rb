# frozen_string_literal: true

require "rails_helper"

RSpec.describe AvailabilityAggregator do
  let(:owner) { create(:user) }
  let(:group) { create(:group, owner: owner, threshold_n: nil, threshold_target: "core") }
  let(:date_range) { Date.new(2025, 1, 6)..Date.new(2025, 1, 8) }

  subject(:aggregator) { described_class.new(group, date_range) }

  describe "#call" do
    context "メンバーも参加可否データもない場合" do
      it "全日付で全カウントが 0 の集計を返す" do
        result = aggregator.call

        date_range.each do |date|
          entry = result[date.iso8601]
          expect(entry).to eq(ok: 0, maybe: 0, ng: 0, none: 0, warning: false)
        end
      end
    end

    context "メンバーがいるが参加可否データがない場合" do
      before do
        create(:membership, :core, user: create(:user), group: group)
        create(:membership, user: create(:user), group: group) # sub
      end

      it "全員が none として集計される" do
        result = aggregator.call

        date_range.each do |date|
          entry = result[date.iso8601]
          expect(entry[:ok]).to eq(0)
          expect(entry[:maybe]).to eq(0)
          expect(entry[:ng]).to eq(0)
          expect(entry[:none]).to eq(2)
        end
      end
    end

    context "各ステータスの集計" do
      let(:user_ok) { create(:user) }
      let(:user_maybe) { create(:user) }
      let(:user_ng) { create(:user) }
      let(:user_none) { create(:user) }

      before do
        create(:membership, :core, user: user_ok, group: group)
        create(:membership, :core, user: user_maybe, group: group)
        create(:membership, user: user_ng, group: group)
        create(:membership, user: user_none, group: group)

        target_date = Date.new(2025, 1, 6)
        create(:availability, :ok, user: user_ok, group: group, date: target_date)
        create(:availability, :maybe, user: user_maybe, group: group, date: target_date)
        create(:availability, :ng, user: user_ng, group: group, date: target_date)
        # user_none は未入力
      end

      it "○/△/×/− の人数を正しく集計する" do
        result = aggregator.call
        entry = result["2025-01-06"]

        expect(entry[:ok]).to eq(1)
        expect(entry[:maybe]).to eq(1)
        expect(entry[:ng]).to eq(1)
        expect(entry[:none]).to eq(1)
      end

      it "データのない日は全員 none になる" do
        result = aggregator.call
        entry = result["2025-01-07"]

        expect(entry[:ok]).to eq(0)
        expect(entry[:maybe]).to eq(0)
        expect(entry[:ng]).to eq(0)
        expect(entry[:none]).to eq(4)
      end
    end

    context "集計の正確性（ok + maybe + ng + none = 総メンバー数）" do
      let(:users) { create_list(:user, 5) }

      before do
        users.each { |u| create(:membership, user: u, group: group) }

        target_date = Date.new(2025, 1, 6)
        create(:availability, :ok, user: users[0], group: group, date: target_date)
        create(:availability, :ok, user: users[1], group: group, date: target_date)
        create(:availability, :maybe, user: users[2], group: group, date: target_date)
        create(:availability, :ng, user: users[3], group: group, date: target_date)
        # users[4] は未入力
      end

      it "合計がグループの総メンバー数と一致する" do
        result = aggregator.call
        entry = result["2025-01-06"]

        total = entry[:ok] + entry[:maybe] + entry[:ng] + entry[:none]
        expect(total).to eq(5)
      end
    end
  end

  describe "Threshold_N 警告判定" do
    let(:core_user1) { create(:user) }
    let(:core_user2) { create(:user) }
    let(:core_user3) { create(:user) }
    let(:sub_user1) { create(:user) }
    let(:sub_user2) { create(:user) }
    let(:target_date) { Date.new(2025, 1, 6) }

    before do
      create(:membership, :core, user: core_user1, group: group)
      create(:membership, :core, user: core_user2, group: group)
      create(:membership, :core, user: core_user3, group: group)
      create(:membership, user: sub_user1, group: group)
      create(:membership, user: sub_user2, group: group)
    end

    context "threshold_n が未設定の場合" do
      it "warning は常に false" do
        create(:availability, :ng, user: core_user1, group: group, date: target_date)
        create(:availability, :ng, user: core_user2, group: group, date: target_date)
        create(:availability, :ng, user: core_user3, group: group, date: target_date)

        result = aggregator.call
        expect(result[target_date.iso8601][:warning]).to be false
      end
    end

    context "threshold_target が 'core' の場合" do
      before do
        group.update!(threshold_n: 2, threshold_target: "core")
      end

      it "Core_Member の×人数が閾値以上で warning が true" do
        create(:availability, :ng, user: core_user1, group: group, date: target_date)
        create(:availability, :ng, user: core_user2, group: group, date: target_date)

        result = aggregator.call
        expect(result[target_date.iso8601][:warning]).to be true
      end

      it "Core_Member の×人数が閾値未満で warning が false" do
        create(:availability, :ng, user: core_user1, group: group, date: target_date)

        result = aggregator.call
        expect(result[target_date.iso8601][:warning]).to be false
      end

      it "Sub_Member の×は閾値判定に含まれない" do
        create(:availability, :ng, user: core_user1, group: group, date: target_date)
        create(:availability, :ng, user: sub_user1, group: group, date: target_date)
        create(:availability, :ng, user: sub_user2, group: group, date: target_date)

        result = aggregator.call
        # Core は 1 人のみ × なので閾値 2 未満 → false
        expect(result[target_date.iso8601][:warning]).to be false
      end
    end

    context "threshold_target が 'all' の場合" do
      before do
        group.update!(threshold_n: 3, threshold_target: "all")
      end

      it "全メンバーの×人数が閾値以上で warning が true" do
        create(:availability, :ng, user: core_user1, group: group, date: target_date)
        create(:availability, :ng, user: sub_user1, group: group, date: target_date)
        create(:availability, :ng, user: sub_user2, group: group, date: target_date)

        result = aggregator.call
        expect(result[target_date.iso8601][:warning]).to be true
      end

      it "全メンバーの×人数が閾値未満で warning が false" do
        create(:availability, :ng, user: core_user1, group: group, date: target_date)
        create(:availability, :ng, user: sub_user1, group: group, date: target_date)

        result = aggregator.call
        expect(result[target_date.iso8601][:warning]).to be false
      end
    end

    context "Owner は Core_Member として扱われる" do
      before do
        create(:membership, :owner, user: owner, group: group)
        group.update!(threshold_n: 1, threshold_target: "core")
      end

      it "Owner の×が Core の閾値判定に含まれる" do
        create(:availability, :ng, user: owner, group: group, date: target_date)

        result = aggregator.call
        expect(result[target_date.iso8601][:warning]).to be true
      end
    end

    context "閾値ちょうどの境界値" do
      before do
        group.update!(threshold_n: 2, threshold_target: "core")
      end

      it "×人数 == threshold_n で warning が true" do
        create(:availability, :ng, user: core_user1, group: group, date: target_date)
        create(:availability, :ng, user: core_user2, group: group, date: target_date)

        result = aggregator.call
        expect(result[target_date.iso8601][:warning]).to be true
      end

      it "×人数 == threshold_n - 1 で warning が false" do
        create(:availability, :ng, user: core_user1, group: group, date: target_date)

        result = aggregator.call
        expect(result[target_date.iso8601][:warning]).to be false
      end
    end
  end

  describe "日付範囲" do
    it "指定した日付範囲の全日付がキーとして含まれる" do
      result = aggregator.call

      expect(result.keys).to contain_exactly("2025-01-06", "2025-01-07", "2025-01-08")
    end

    it "1日だけの範囲でも動作する" do
      single_day = Date.new(2025, 1, 6)..Date.new(2025, 1, 6)
      agg = described_class.new(group, single_day)
      result = agg.call

      expect(result.keys).to eq(["2025-01-06"])
    end
  end
end
