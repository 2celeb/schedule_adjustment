# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Availability, type: :model do
  describe 'リレーション' do
    it { expect(described_class.reflect_on_association(:user).macro).to eq :belongs_to }
    it { expect(described_class.reflect_on_association(:group).macro).to eq :belongs_to }
    it { expect(described_class.reflect_on_association(:availability_logs).macro).to eq :has_many }
  end

  describe 'バリデーション' do
    describe 'date' do
      it '存在しない場合は無効' do
        availability = build(:availability, date: nil)
        expect(availability).not_to be_valid
        expect(availability.errors[:date]).to be_present
      end
    end

    describe 'status' do
      [1, 0, -1].each do |valid_status|
        it "#{valid_status} を許可する" do
          availability = build(:availability, status: valid_status)
          expect(availability).to be_valid
        end
      end

      it 'nil を許可する' do
        availability = build(:availability, status: nil)
        expect(availability).to be_valid
      end

      it '不正な値（2）を拒否する' do
        availability = build(:availability, status: 2)
        expect(availability).not_to be_valid
        expect(availability.errors[:status]).to be_present
      end

      it '不正な値（-2）を拒否する' do
        availability = build(:availability, status: -2)
        expect(availability).not_to be_valid
      end
    end

    describe 'user_id の group_id, date スコープ一意性' do
      it '同じユーザー・グループ・日付の組み合わせで重複できない' do
        availability = create(:availability)
        duplicate = build(:availability,
                          user: availability.user,
                          group: availability.group,
                          date: availability.date)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:user_id]).to be_present
      end

      it '同じユーザー・グループで異なる日付は許可される' do
        availability = create(:availability, date: Date.current)
        another = build(:availability,
                        user: availability.user,
                        group: availability.group,
                        date: Date.current + 1.day)
        expect(another).to be_valid
      end
    end
  end

  describe 'ファクトリ' do
    it 'デフォルトファクトリが有効なレコードを作成する' do
      expect(build(:availability)).to be_valid
    end
  end

  describe '変更履歴記録コールバック' do
    let(:user) { create(:user) }
    let(:group) { create(:group) }

    before do
      Current.user_agent = 'TestBrowser/1.0'
      Current.ip_address = '203.0.113.1'
    end

    after do
      Current.reset
    end

    describe '新規作成時' do
      it 'status=1（○）で AvailabilityLog を作成する' do
        expect {
          create(:availability, user: user, group: group, status: 1)
        }.to change(AvailabilityLog, :count).by(1)
      end

      it 'status=0（△）で AvailabilityLog を作成する' do
        expect {
          create(:availability, user: user, group: group, status: 0)
        }.to change(AvailabilityLog, :count).by(1)
      end

      it 'status=-1（×）で AvailabilityLog を作成する' do
        expect {
          create(:availability, user: user, group: group, status: -1)
        }.to change(AvailabilityLog, :count).by(1)
      end

      it 'status が nil の場合は AvailabilityLog を作成しない' do
        expect {
          create(:availability, user: user, group: group, status: nil)
        }.not_to change(AvailabilityLog, :count)
      end

      it '作成されたログに正しい値が記録される' do
        availability = create(:availability, user: user, group: group, status: 1, comment: 'テスト')
        log = availability.availability_logs.last

        expect(log).to have_attributes(
          user: user,
          old_status: nil,
          new_status: 1,
          old_comment: nil,
          new_comment: 'テスト',
          user_agent: 'TestBrowser/1.0',
          geo_region: 'unknown'
        )
        expect(log.ip_address.to_s).to eq '203.0.113.1'
      end

      it 'status=0 のログに old_status=nil, new_status=0 が記録される' do
        availability = create(:availability, user: user, group: group, status: 0, comment: '未定')
        log = availability.availability_logs.last

        expect(log).to have_attributes(
          old_status: nil,
          new_status: 0,
          old_comment: nil,
          new_comment: '未定'
        )
      end
    end

    describe 'status 変更時' do
      let!(:availability) { create(:availability, user: user, group: group, status: 1) }

      before do
        AvailabilityLog.delete_all
      end

      it 'status が変更された場合に AvailabilityLog を作成する' do
        expect {
          availability.update!(status: -1)
        }.to change(AvailabilityLog, :count).by(1)
      end

      it 'status が変更されていない場合は AvailabilityLog を作成しない' do
        expect {
          availability.update!(status: 1)
        }.not_to change(AvailabilityLog, :count)
      end

      it '変更前後の status が正しく記録される' do
        availability.update!(status: 0)
        log = availability.availability_logs.last

        expect(log).to have_attributes(
          old_status: 1,
          new_status: 0
        )
      end

      it 'status を nil に変更した場合もログが記録される' do
        availability.update!(status: nil)
        log = availability.availability_logs.last

        expect(log).to have_attributes(
          old_status: 1,
          new_status: nil
        )
      end
    end

    describe 'comment 変更時' do
      let!(:availability) { create(:availability, user: user, group: group, status: -1, comment: '出張') }

      before do
        AvailabilityLog.delete_all
      end

      it 'comment が変更された場合に AvailabilityLog を作成する' do
        expect {
          availability.update!(comment: '会議')
        }.to change(AvailabilityLog, :count).by(1)
      end

      it '変更前後の comment が正しく記録される' do
        availability.update!(comment: '会議')
        log = availability.availability_logs.last

        expect(log).to have_attributes(
          old_status: -1,
          new_status: -1,
          old_comment: '出張',
          new_comment: '会議'
        )
      end

      it 'comment を nil に変更した場合もログが記録される' do
        availability.update!(comment: nil)
        log = availability.availability_logs.last

        expect(log).to have_attributes(
          old_comment: '出張',
          new_comment: nil
        )
      end
    end

    describe 'status と comment の同時変更' do
      let!(:availability) { create(:availability, user: user, group: group, status: 1, comment: nil) }

      before do
        AvailabilityLog.delete_all
      end

      it '1つの AvailabilityLog が作成される' do
        expect {
          availability.update!(status: -1, comment: '出張のため')
        }.to change(AvailabilityLog, :count).by(1)
      end

      it '両方の変更が正しく記録される' do
        availability.update!(status: -1, comment: '出張のため')
        log = availability.availability_logs.last

        expect(log).to have_attributes(
          old_status: 1,
          new_status: -1,
          old_comment: nil,
          new_comment: '出張のため'
        )
      end
    end

    describe '連続変更時の履歴蓄積' do
      it '複数回の変更で正しい履歴が蓄積される' do
        availability = create(:availability, user: user, group: group, status: 1)
        availability.update!(status: 0, comment: '未定')
        availability.update!(status: -1, comment: '出張')
        availability.update!(comment: '出張（終日）')

        logs = availability.availability_logs.order(:created_at)
        expect(logs.size).to eq 4

        # 1回目: 新規作成（nil → 1）
        expect(logs[0]).to have_attributes(old_status: nil, new_status: 1, old_comment: nil, new_comment: nil)
        # 2回目: ○ → △ + コメント追加
        expect(logs[1]).to have_attributes(old_status: 1, new_status: 0, old_comment: nil, new_comment: '未定')
        # 3回目: △ → × + コメント変更
        expect(logs[2]).to have_attributes(old_status: 0, new_status: -1, old_comment: '未定', new_comment: '出張')
        # 4回目: コメントのみ変更
        expect(logs[3]).to have_attributes(old_status: -1, new_status: -1, old_comment: '出張', new_comment: '出張（終日）')
      end
    end

    describe 'リクエスト情報の記録' do
      it 'Current の user_agent が記録される' do
        Current.user_agent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)'
        availability = create(:availability, user: user, group: group, status: 1)
        log = availability.availability_logs.last

        expect(log.user_agent).to eq 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)'
      end

      it 'Current の ip_address が記録される' do
        Current.ip_address = '198.51.100.42'
        availability = create(:availability, user: user, group: group, status: 1)
        log = availability.availability_logs.last

        expect(log.ip_address.to_s).to eq '198.51.100.42'
      end

      it 'Current が未設定の場合は nil が記録される' do
        Current.reset
        availability = create(:availability, user: user, group: group, status: 1)
        log = availability.availability_logs.last

        expect(log.user_agent).to be_nil
        expect(log.ip_address).to be_nil
        expect(log.geo_region).to be_nil
      end

      it 'プライベート IP の場合は geo_region が "private" になる' do
        Current.ip_address = '192.168.1.100'
        availability = create(:availability, user: user, group: group, status: 1)
        log = availability.availability_logs.last

        expect(log.geo_region).to eq 'private'
      end

      it 'ループバック IP の場合は geo_region が "loopback" になる' do
        Current.ip_address = '127.0.0.1'
        availability = create(:availability, user: user, group: group, status: 1)
        log = availability.availability_logs.last

        expect(log.geo_region).to eq 'loopback'
      end

      it '変更ごとに異なるリクエスト情報が記録される' do
        availability = create(:availability, user: user, group: group, status: 1)

        Current.user_agent = 'MobileApp/2.0'
        Current.ip_address = '10.0.0.5'
        availability.update!(status: -1)

        logs = availability.availability_logs.order(:created_at)
        expect(logs[0].user_agent).to eq 'TestBrowser/1.0'
        expect(logs[0].geo_region).to eq 'unknown'
        expect(logs[1].user_agent).to eq 'MobileApp/2.0'
        expect(logs[1].geo_region).to eq 'private'
      end
    end

    describe '関連のない属性の変更' do
      let!(:availability) { create(:availability, user: user, group: group, status: 1) }

      before do
        AvailabilityLog.delete_all
      end

      it 'auto_synced のみの変更ではログを作成しない' do
        expect {
          availability.update!(auto_synced: true)
        }.not_to change(AvailabilityLog, :count)
      end
    end
  end
end
