# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventDay, type: :model do
  describe 'リレーション' do
    it { expect(described_class.reflect_on_association(:group).macro).to eq :belongs_to }
  end

  describe 'バリデーション' do
    describe 'date' do
      it '存在しない場合は無効' do
        event_day = build(:event_day, date: nil)
        expect(event_day).not_to be_valid
        expect(event_day.errors[:date]).to be_present
      end
    end

    describe 'group_id の date スコープ一意性' do
      it '同じグループ・日付の組み合わせで重複できない' do
        event_day = create(:event_day)
        duplicate = build(:event_day, group: event_day.group, date: event_day.date)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:group_id]).to be_present
      end

      it '同じグループで異なる日付は許可される' do
        event_day = create(:event_day, date: Date.current)
        another = build(:event_day, group: event_day.group, date: Date.current + 1.day)
        expect(another).to be_valid
      end

      it '異なるグループで同じ日付は許可される' do
        create(:event_day, date: Date.current)
        another = build(:event_day, date: Date.current)
        expect(another).to be_valid
      end
    end
  end

  describe 'ファクトリ' do
    it 'デフォルトファクトリが有効なレコードを作成する' do
      expect(build(:event_day)).to be_valid
    end
  end
end
