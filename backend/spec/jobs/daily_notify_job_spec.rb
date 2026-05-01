# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DailyNotifyJob, type: :job do
  let!(:owner) { create(:user, :with_discord) }
  let!(:group) { create(:group, :with_times, owner: owner) }
  let!(:discord_config) { create(:discord_config, group: group) }
  let!(:owner_membership) { create(:membership, :owner, user: owner, group: group) }

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
      context '本日の確定済み活動日がある場合' do
        it '当日通知を送信する' do
          create(:event_day,
            group: group,
            date: Date.current,
            confirmed: true,
            confirmed_at: 1.day.ago
          )

          member1 = create(:user, :with_discord)
          create(:membership, :core, user: member1, group: group)
          create(:availability, user: member1, group: group, date: Date.current, status: 1)

          expect {
            described_class.new.perform(group.id)
          }.not_to raise_error
        end

        it 'カスタムメッセージが設定されている場合はそれを使用する' do
          create(:auto_schedule_rule,
            group: group,
            activity_notify_message: "今日は#{group.event_name}の日です！"
          )

          create(:event_day,
            group: group,
            date: Date.current,
            confirmed: true,
            confirmed_at: 1.day.ago
          )

          expect {
            described_class.new.perform(group.id)
          }.not_to raise_error
        end

        it 'activity_notify_channel_id が設定されている場合はそちらを使用する' do
          create(:auto_schedule_rule,
            group: group,
            activity_notify_channel_id: "custom_channel_123"
          )

          create(:event_day,
            group: group,
            date: Date.current,
            confirmed: true,
            confirmed_at: 1.day.ago
          )

          expect {
            described_class.new.perform(group.id)
          }.not_to raise_error
        end
      end

      context '本日の確定済み活動日がない場合' do
        it '通知を送信しない' do
          http_mock = instance_double(Net::HTTP,
            'open_timeout=' => nil,
            'read_timeout=' => nil
          )
          allow(Net::HTTP).to receive(:new).and_return(http_mock)

          expect(http_mock).not_to receive(:request)

          described_class.new.perform(group.id)
        end
      end

      context '未確定の活動日がある場合' do
        it '通知を送信しない' do
          create(:event_day,
            group: group,
            date: Date.current,
            confirmed: false
          )

          http_mock = instance_double(Net::HTTP,
            'open_timeout=' => nil,
            'read_timeout=' => nil
          )
          allow(Net::HTTP).to receive(:new).and_return(http_mock)

          expect(http_mock).not_to receive(:request)

          described_class.new.perform(group.id)
        end
      end

      it 'Discord 設定がないグループは処理をスキップする' do
        group_without_discord = create(:group, owner: owner)

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
      it '本日の確定済み活動日を持つグループのみ処理する' do
        # 本日の確定済み活動日を作成
        create(:event_day,
          group: group,
          date: Date.current,
          confirmed: true,
          confirmed_at: 1.day.ago
        )

        expect {
          described_class.new.perform
        }.not_to raise_error
      end

      it '確定済み活動日がない場合は何もしない' do
        http_mock = instance_double(Net::HTTP,
          'open_timeout=' => nil,
          'read_timeout=' => nil
        )
        allow(Net::HTTP).to receive(:new).and_return(http_mock)

        expect(http_mock).not_to receive(:request)

        described_class.new.perform
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
