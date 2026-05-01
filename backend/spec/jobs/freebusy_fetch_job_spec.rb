# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FreebusyFetchJob, type: :job do
  let!(:owner) { create(:user, :with_google) }
  let!(:group) { create(:group, owner: owner) }
  let(:date_range_start) { '2025-01-06' }
  let(:date_range_end) { '2025-01-31' }
  let(:sync_result) { { synced_users: 2, cached_dates: 52 } }

  describe '#perform' do
    context '正常系' do
      it 'FreebusySyncService を正しいパラメータで呼び出す' do
        service = instance_double(FreebusySyncService, call: sync_result)
        expected_range = Date.parse(date_range_start)..Date.parse(date_range_end)

        expect(FreebusySyncService).to receive(:new)
          .with(group, expected_range, force: false)
          .and_return(service)

        described_class.new.perform(group.id, date_range_start, date_range_end)
      end

      it 'force パラメータを FreebusySyncService に渡す' do
        service = instance_double(FreebusySyncService, call: sync_result)
        expected_range = Date.parse(date_range_start)..Date.parse(date_range_end)

        expect(FreebusySyncService).to receive(:new)
          .with(group, expected_range, force: true)
          .and_return(service)

        described_class.new.perform(group.id, date_range_start, date_range_end, force: true)
      end
    end

    context '日付範囲のシリアライゼーション' do
      it '文字列の日付を正しく Date オブジェクトに変換する' do
        service = instance_double(FreebusySyncService, call: sync_result)

        expect(FreebusySyncService).to receive(:new) do |grp, range, **opts|
          expect(grp).to eq(group)
          expect(range.first).to eq(Date.new(2025, 1, 6))
          expect(range.last).to eq(Date.new(2025, 1, 31))
          expect(range.first).to be_a(Date)
          expect(range.last).to be_a(Date)
          service
        end

        described_class.new.perform(group.id, '2025-01-06', '2025-01-31')
      end
    end

    context 'エラーハンドリング' do
      it 'グループが存在しない場合は ActiveRecord::RecordNotFound で破棄される' do
        # discard_on ActiveRecord::RecordNotFound が設定されていることを確認
        expect(described_class.rescue_handlers).to satisfy { |handlers|
          handlers.any? { |h| h[0] == 'ActiveRecord::RecordNotFound' }
        }
      end

      it 'TokenRefreshError 発生時はエラーを握りつぶしてログ記録する' do
        service = instance_double(FreebusySyncService)
        allow(FreebusySyncService).to receive(:new).and_return(service)
        allow(service).to receive(:call)
          .and_raise(FreebusySyncService::TokenRefreshError, 'リフレッシュトークンが無効')

        expect(Rails.logger).to receive(:warn).with(/トークンリフレッシュ失敗/)

        expect {
          described_class.new.perform(group.id, date_range_start, date_range_end)
        }.not_to raise_error
      end

      it 'FreeBusyApiError 発生時はエラーを握りつぶしてログ記録する' do
        service = instance_double(FreebusySyncService)
        allow(FreebusySyncService).to receive(:new).and_return(service)
        allow(service).to receive(:call)
          .and_raise(FreebusySyncService::FreeBusyApiError, 'API レート制限')

        expect(Rails.logger).to receive(:warn).with(/FreeBusy API エラー/)

        expect {
          described_class.new.perform(group.id, date_range_start, date_range_end)
        }.not_to raise_error
      end
    end
  end

  describe 'ジョブの設定' do
    it 'default キューに投入される' do
      expect(described_class.new.queue_name).to eq('default')
    end

    it 'ApplicationJob を継承している' do
      expect(described_class.superclass).to eq(ApplicationJob)
    end
  end
end
