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
end
