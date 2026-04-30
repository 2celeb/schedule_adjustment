# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CalendarCache, type: :model do
  describe '定数' do
    it 'CACHE_TTL が15分であること' do
      expect(described_class::CACHE_TTL).to eq 15.minutes
    end
  end

  describe 'リレーション' do
    it { expect(described_class.reflect_on_association(:user).macro).to eq :belongs_to }
    it { expect(described_class.reflect_on_association(:group).macro).to eq :belongs_to }
  end

  describe 'バリデーション' do
    describe 'date' do
      it '存在しない場合は無効' do
        cache = build(:calendar_cache, date: nil)
        expect(cache).not_to be_valid
        expect(cache.errors[:date]).to be_present
      end
    end

    describe 'user_id の group_id, date スコープ一意性' do
      it '同じユーザー・グループ・日付の組み合わせで重複できない' do
        cache = create(:calendar_cache)
        duplicate = build(:calendar_cache,
                          user: cache.user,
                          group: cache.group,
                          date: cache.date)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:user_id]).to be_present
      end

      it '同じユーザー・グループで異なる日付は許可される' do
        cache = create(:calendar_cache, date: Date.current)
        another = build(:calendar_cache,
                        user: cache.user,
                        group: cache.group,
                        date: Date.current + 1.day)
        expect(another).to be_valid
      end
    end
  end

  describe 'インスタンスメソッド' do
    describe '#stale?' do
      it 'fetched_at が nil の場合は true を返す' do
        cache = build(:calendar_cache, fetched_at: nil)
        expect(cache.stale?).to be true
      end

      it 'fetched_at が15分以上前の場合は true を返す' do
        cache = build(:calendar_cache, fetched_at: 20.minutes.ago)
        expect(cache.stale?).to be true
      end

      it 'fetched_at が15分未満の場合は false を返す' do
        cache = build(:calendar_cache, fetched_at: 5.minutes.ago)
        expect(cache.stale?).to be false
      end

      it ':stale トレイトで古いキャッシュを作成できる' do
        cache = build(:calendar_cache, :stale)
        expect(cache.stale?).to be true
      end

      it ':fresh トレイトで新しいキャッシュを作成できる' do
        cache = build(:calendar_cache, :fresh)
        expect(cache.stale?).to be false
      end
    end
  end

  describe 'ファクトリ' do
    it 'デフォルトファクトリが有効なレコードを作成する' do
      expect(build(:calendar_cache)).to be_valid
    end
  end
end
