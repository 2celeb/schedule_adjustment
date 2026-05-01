# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RemindJob, type: :job do
  let!(:owner) { create(:user, :with_discord) }
  let!(:group) { create(:group, :with_times, owner: owner) }
  let!(:discord_config) { create(:discord_config, group: group) }
  let!(:owner_membership) { create(:membership, :owner, user: owner, group: group) }

  let!(:rule) do
    create(:auto_schedule_rule,
      group: group,
      max_days_per_week: 3,
      min_days_per_week: 1,
      week_start_day: 1,
      confirm_days_before: 3,
      remind_days_before_confirm: 2
    )
  end

  # Net::HTTP のモック
  before do
    require 'net/http'
    allow(Net::HTTP).to receive(:new).and_return(
      instance_double(Net::HTTP,
        'open_timeout=' => nil,
        'read_timeout=' => nil,
        request: instance_double(Net::HTTPSuccess, is_a?: true, code: '200', body: '{}')
      )
    )
  end

  describe '#perform' do
    context '特定のグループ ID を指定した場合' do
      context 'リマインド対象日の場合' do
        it '未入力メンバーへのチャンネルリマインドを送信する' do
          # メンバーを作成（未入力状態）
          member1 = create(:user, :with_discord)
          create(:membership, :core, user: member1, group: group)

          # リマインド対象日に設定
          # confirm_date = next_week_start - 3日
          # remind_start_date = confirm_date - 2日
          service = AutoScheduleService.new(group)
          next_week_start = service.next_week_start(Date.current)
          confirm_date = service.confirm_date_for(next_week_start)
          remind_start_date = confirm_date - 2.days

          travel_to remind_start_date do
            expect {
              described_class.new.perform(group.id)
            }.not_to raise_error
          end
        end
      end

      context 'リマインド対象日でない場合' do
        it '通知を送信しない' do
          member1 = create(:user, :with_discord)
          create(:membership, :core, user: member1, group: group)

          # confirm_days_before=3, remind_days_before_confirm=2 の場合:
          # confirm_date = next_week_start - 3日
          # remind_start_date = confirm_date - 2日 = next_week_start - 5日
          # next_week_start の6日前（= remind_start_date の1日前）に設定すれば
          # リマインド対象外になる
          #
          # week_start_day=1（月曜）の場合、次の月曜を基準に計算する
          # 月曜の6日前 = 火曜 → confirm_date = 金曜、remind_start = 水曜
          # 火曜は水曜より前なのでリマインド対象外

          # 次の week_start_day（月曜）を見つける
          target_monday = Date.current
          target_monday += 1.day until target_monday.wday == rule.week_start_day
          # confirm_date = target_monday - 3日 = 金曜
          # remind_start = 金曜 - 2日 = 水曜
          # 水曜の前日 = 火曜に travel
          before_remind = target_monday - (rule.confirm_days_before + rule.remind_days_before_confirm + 1).days

          travel_to before_remind do
            http_mock = instance_double(Net::HTTP,
              'open_timeout=' => nil,
              'read_timeout=' => nil
            )
            allow(Net::HTTP).to receive(:new).and_return(http_mock)

            # Bot への通知が呼ばれないことを確認
            expect(http_mock).not_to receive(:request)

            described_class.new.perform(group.id)
          end
        end
      end

      context '全メンバーが入力済みの場合' do
        it '通知を送信しない' do
          member1 = create(:user, :with_discord)
          create(:membership, :core, user: member1, group: group)

          service = AutoScheduleService.new(group)
          next_week_start = service.next_week_start(Date.current)
          confirm_date = service.confirm_date_for(next_week_start)
          remind_start_date = confirm_date - 2.days

          # 対象週の全日に入力
          week_end = next_week_start + 6.days
          (next_week_start..week_end).each do |date|
            create(:availability, user: owner, group: group, date: date, status: 1)
            create(:availability, user: member1, group: group, date: date, status: 1)
          end

          travel_to remind_start_date do
            http_mock = instance_double(Net::HTTP,
              'open_timeout=' => nil,
              'read_timeout=' => nil
            )
            allow(Net::HTTP).to receive(:new).and_return(http_mock)

            expect(http_mock).not_to receive(:request)

            described_class.new.perform(group.id)
          end
        end
      end

      it 'ルールがないグループは処理をスキップする' do
        group_without_rule = create(:group, owner: owner)
        create(:discord_config, group: group_without_rule)

        expect {
          described_class.new.perform(group_without_rule.id)
        }.not_to raise_error
      end

      it 'Discord 設定がないグループは処理をスキップする' do
        group_without_discord = create(:group, owner: owner)
        create(:auto_schedule_rule, group: group_without_discord)

        expect {
          described_class.new.perform(group_without_discord.id)
        }.not_to raise_error
      end

      it '存在しないグループ ID の場合はエラーにならない' do
        expect {
          described_class.new.perform(999999)
        }.not_to raise_error
      end
    end

    context 'グループ ID を指定しない場合（全グループ処理）' do
      it 'エラーにならない' do
        expect {
          described_class.new.perform
        }.not_to raise_error
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
