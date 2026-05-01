# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutoScheduleService, type: :service do
  let!(:owner) { create(:user) }
  let!(:group) { create(:group, :with_times, owner: owner) }
  let!(:rule) do
    create(:auto_schedule_rule,
      group: group,
      max_days_per_week: 3,
      min_days_per_week: 1,
      week_start_day: 1, # 月曜始まり
      confirm_days_before: 3,
      deprioritized_days: [],
      excluded_days: []
    )
  end

  # テスト用メンバーを作成するヘルパー
  def create_members(count)
    count.times.map do
      user = create(:user)
      create(:membership, user: user, group: group, role: 'core')
      user
    end
  end

  # 参加可否を設定するヘルパー
  def set_availability(user, date, status)
    create(:availability, user: user, group: group, date: date, status: status)
  end

  describe '#generate_for_week' do
    context 'ルールが存在しない場合' do
      it '空配列を返す' do
        group_without_rule = create(:group, owner: owner)
        service = described_class.new(group_without_rule)

        result = service.generate_for_week(Date.new(2026, 5, 6))
        expect(result).to eq([])
      end
    end

    context '参加可否データがある場合' do
      let(:members) { create_members(5) }
      # 2026-05-04 (月) 〜 2026-05-10 (日) の週
      let(:monday) { Date.new(2026, 5, 4) }

      before do
        # 月曜: 全員○
        members.each { |m| set_availability(m, monday, 1) }
        # 火曜: 3人○、2人×
        members[0..2].each { |m| set_availability(m, monday + 1, 1) }
        members[3..4].each { |m| set_availability(m, monday + 1, -1) }
        # 水曜: 4人○、1人△
        members[0..3].each { |m| set_availability(m, monday + 2, 1) }
        set_availability(members[4], monday + 2, 0)
        # 木曜: 2人○、3人×
        members[0..1].each { |m| set_availability(m, monday + 3, 1) }
        members[2..4].each { |m| set_availability(m, monday + 3, -1) }
        # 金〜日: データなし
      end

      it 'スコアの高い日から max_days_per_week 個を選択する' do
        service = described_class.new(group)
        result = service.generate_for_week(monday)

        expect(result.size).to eq(3) # max_days_per_week = 3
        dates = result.map(&:date)
        # 月曜(5.0) > 水曜(4.5) > 火曜(1.0) > 木曜(-1.0)
        expect(dates).to include(monday)       # 月曜: スコア 5.0
        expect(dates).to include(monday + 2)   # 水曜: スコア 4.5
        expect(dates).to include(monday + 1)   # 火曜: スコア 1.0
      end

      it 'auto_generated が true に設定される' do
        service = described_class.new(group)
        result = service.generate_for_week(monday)

        result.each do |ed|
          expect(ed.auto_generated).to be true
        end
      end

      it 'EventDay レコードが作成される' do
        service = described_class.new(group)

        expect {
          service.generate_for_week(monday)
        }.to change(EventDay, :count).by(3)
      end
    end

    context 'excluded_days が設定されている場合' do
      let(:members) { create_members(3) }
      let(:monday) { Date.new(2026, 5, 4) }

      before do
        rule.update!(excluded_days: [0, 6]) # 日曜・土曜を除外
        # 全日に全員○を設定
        (0..6).each do |i|
          members.each { |m| set_availability(m, monday + i, 1) }
        end
      end

      it '除外曜日は活動日にならない（min 充足時）' do
        service = described_class.new(group)
        result = service.generate_for_week(monday)

        dates = result.map(&:date)
        wdays = dates.map(&:wday)
        expect(wdays).not_to include(0) # 日曜
        expect(wdays).not_to include(6) # 土曜
      end

      it 'min 未達の場合は除外曜日も活動日になる' do
        rule.update!(
          excluded_days: [1, 2, 3, 4, 5], # 月〜金を除外
          min_days_per_week: 2
        )

        service = described_class.new(group)
        result = service.generate_for_week(monday)

        expect(result.size).to be >= 2
      end
    end

    context 'deprioritized_days が設定されている場合' do
      let(:members) { create_members(3) }
      let(:monday) { Date.new(2026, 5, 4) }

      before do
        rule.update!(deprioritized_days: [5]) # 金曜を後回し
        # 全日に全員○を設定（同スコア）
        (0..6).each do |i|
          members.each { |m| set_availability(m, monday + i, 1) }
        end
      end

      it '優先度を下げた曜日は後回しになる' do
        service = described_class.new(group)
        result = service.generate_for_week(monday)

        dates = result.map(&:date)
        friday = monday + 4 # 金曜
        # max_days_per_week=3 なので、同スコアの場合は日付順で選ばれる
        # 金曜はペナルティ -10 があるので選ばれにくい
        expect(dates).not_to include(friday)
      end
    end

    context 'max_days_per_week と min_days_per_week の制約' do
      let(:members) { create_members(3) }
      let(:monday) { Date.new(2026, 5, 4) }

      before do
        members.each { |m| set_availability(m, monday, 1) }
      end

      it 'max_days_per_week を超えない' do
        rule.update!(max_days_per_week: 2)
        service = described_class.new(group)
        result = service.generate_for_week(monday)

        expect(result.size).to be <= 2
      end

      it 'min_days_per_week 以上になる' do
        rule.update!(min_days_per_week: 2)
        service = described_class.new(group)
        result = service.generate_for_week(monday)

        expect(result.size).to be >= 2
      end
    end

    context '既存の EventDay がある場合' do
      let(:members) { create_members(3) }
      let(:monday) { Date.new(2026, 5, 4) }

      before do
        members.each { |m| set_availability(m, monday, 1) }
        create(:event_day, group: group, date: monday)
      end

      it '既存の EventDay を再利用する（重複作成しない）' do
        service = described_class.new(group)

        expect {
          service.generate_for_week(monday)
        }.to change(EventDay, :count).by(2) # 3 - 1(既存) = 2
      end
    end
  end

  describe '#confirm_date_for' do
    it '週の開始日の confirm_days_before 日前を返す' do
      service = described_class.new(group)
      # 2026-05-04 (月) を含む週 → 週の開始日は 2026-05-04 (月)
      # confirm_days_before = 3 → 2026-05-01 (金)
      result = service.confirm_date_for(Date.new(2026, 5, 4))
      expect(result).to eq(Date.new(2026, 5, 4) - 3.days)
    end

    it 'ルールがない場合は nil を返す' do
      group_without_rule = create(:group, owner: owner)
      service = described_class.new(group_without_rule)

      result = service.confirm_date_for(Date.new(2026, 5, 4))
      expect(result).to be_nil
    end
  end

  describe '#next_week_start' do
    it 'week_start_day=1（月曜）の場合、次の月曜を返す' do
      service = described_class.new(group)
      # 2026-05-03 (日) → 次の月曜は 2026-05-04
      result = service.next_week_start(Date.new(2026, 5, 3))
      expect(result).to eq(Date.new(2026, 5, 4))
      expect(result.wday).to eq(1)
    end

    it '当日が week_start_day の場合はその日を返す' do
      service = described_class.new(group)
      # 2026-05-04 (月) → 当日が月曜なのでそのまま
      result = service.next_week_start(Date.new(2026, 5, 4))
      expect(result).to eq(Date.new(2026, 5, 4))
    end

    it 'week_start_day=0（日曜）の場合' do
      rule.update!(week_start_day: 0)
      service = described_class.new(group)
      # 2026-05-04 (月) → 次の日曜は 2026-05-10
      result = service.next_week_start(Date.new(2026, 5, 4))
      expect(result).to eq(Date.new(2026, 5, 10))
      expect(result.wday).to eq(0)
    end
  end
end
