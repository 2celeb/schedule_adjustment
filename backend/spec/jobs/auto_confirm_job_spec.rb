# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutoConfirmJob, type: :job do
  let!(:owner) { create(:user) }
  let!(:group) { create(:group, :with_times, owner: owner) }

  describe '#perform' do
    context '特定のグループ ID を指定した場合' do
      let!(:rule) do
        create(:auto_schedule_rule,
          group: group,
          max_days_per_week: 3,
          min_days_per_week: 1,
          week_start_day: 1,
          confirm_days_before: 3
        )
      end

      it '活動日を生成して確定する' do
        # メンバーと参加可否を作成
        users = 3.times.map { create(:user) }
        users.each do |u|
          create(:membership, user: u, group: group, role: 'core')
        end

        # 次の月曜を含む週のデータを作成
        next_monday = Date.current
        next_monday += 1.day until next_monday.wday == 1
        users.each do |u|
          create(:availability, user: u, group: group, date: next_monday, status: 1)
        end

        expect {
          described_class.new.perform(group.id)
        }.to change(EventDay, :count)

        # 確定されていることを確認
        event_days = group.event_days.where(confirmed: true)
        expect(event_days).to be_present
        event_days.each do |ed|
          expect(ed.confirmed).to be true
          expect(ed.confirmed_at).to be_present
          expect(ed.auto_generated).to be true
        end
      end

      it 'ルールがないグループは処理をスキップする' do
        group_without_rule = create(:group, owner: owner)

        expect {
          described_class.new.perform(group_without_rule.id)
        }.not_to change(EventDay, :count)
      end

      it '存在しないグループ ID の場合はエラーにならない' do
        expect {
          described_class.new.perform(999999)
        }.not_to raise_error
      end
    end

    context 'グループ ID を指定しない場合（全グループ処理）' do
      it '確定タイミングに達したグループのみ処理する' do
        # このテストは should_confirm? のロジックに依存するため、
        # 日付を固定してテストする
        rule = create(:auto_schedule_rule,
          group: group,
          max_days_per_week: 2,
          min_days_per_week: 1,
          week_start_day: 1,
          confirm_days_before: 3
        )

        # should_confirm? が false を返す場合は処理されない
        allow_any_instance_of(AutoScheduleService).to receive(:confirm_date_for).and_return(Date.current + 1.day)

        expect {
          described_class.new.perform
        }.not_to change(EventDay, :count)
      end
    end
  end

  describe 'ジョブのキュー設定' do
    it 'default キューに投入される' do
      expect(described_class.new.queue_name).to eq('default')
    end
  end

  describe 'リトライ設定' do
    it 'StandardError でリトライする' do
      retry_config = described_class.rescue_handlers.find { |h| h[0] == StandardError.name }
      expect(retry_config).to be_present
    end
  end
end
