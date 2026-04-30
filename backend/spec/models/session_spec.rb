# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Session, type: :model do
  describe 'リレーション' do
    it { expect(described_class.reflect_on_association(:user).macro).to eq :belongs_to }
  end

  describe 'バリデーション' do
    describe 'token' do
      it '存在しない場合は無効' do
        session = build(:session, token: nil)
        expect(session).not_to be_valid
        expect(session.errors[:token]).to be_present
      end

      it '空文字の場合は無効' do
        session = build(:session, token: '')
        expect(session).not_to be_valid
      end

      it '一意であること' do
        existing = create(:session)
        duplicate = build(:session, token: existing.token)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:token]).to be_present
      end
    end

    describe 'expires_at' do
      it '存在しない場合は無効' do
        session = build(:session, expires_at: nil)
        expect(session).not_to be_valid
        expect(session.errors[:expires_at]).to be_present
      end
    end
  end

  describe 'スコープ' do
    describe '.active' do
      it '有効期限内のセッションを返す' do
        active_session = create(:session, expires_at: 1.day.from_now)
        create(:session, :expired)

        expect(described_class.active).to contain_exactly(active_session)
      end

      it '期限切れのセッションを除外する' do
        create(:session, :expired)
        expect(described_class.active).to be_empty
      end
    end
  end

  describe 'インスタンスメソッド' do
    describe '#expired?' do
      it '期限切れの場合は true を返す' do
        session = build(:session, expires_at: 1.hour.ago)
        expect(session.expired?).to be true
      end

      it '有効期限内の場合は false を返す' do
        session = build(:session, expires_at: 1.hour.from_now)
        expect(session.expired?).to be false
      end

      it '期限がちょうど現在時刻の場合は true を返す' do
        session = build(:session, expires_at: Time.current)
        expect(session.expired?).to be true
      end
    end
  end

  describe 'ファクトリ' do
    it 'デフォルトファクトリが有効なレコードを作成する' do
      expect(build(:session)).to be_valid
    end

    it ':expired トレイトが期限切れセッションを作成する' do
      session = build(:session, :expired)
      expect(session.expired?).to be true
    end
  end
end
