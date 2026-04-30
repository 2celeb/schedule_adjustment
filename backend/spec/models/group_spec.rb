# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Group, type: :model do
  describe 'リレーション' do
    it { expect(described_class.reflect_on_association(:owner).macro).to eq :belongs_to }
    it { expect(described_class.reflect_on_association(:memberships).macro).to eq :has_many }
    it { expect(described_class.reflect_on_association(:members).macro).to eq :has_many }
    it { expect(described_class.reflect_on_association(:availabilities).macro).to eq :has_many }
    it { expect(described_class.reflect_on_association(:event_days).macro).to eq :has_many }
    it { expect(described_class.reflect_on_association(:auto_schedule_rule).macro).to eq :has_one }
    it { expect(described_class.reflect_on_association(:discord_config).macro).to eq :has_one }
    it { expect(described_class.reflect_on_association(:calendar_caches).macro).to eq :has_many }

    it 'owner は User モデルを参照する' do
      assoc = described_class.reflect_on_association(:owner)
      expect(assoc.options[:class_name]).to eq 'User'
    end

    it 'members は memberships を通じて取得される' do
      assoc = described_class.reflect_on_association(:members)
      expect(assoc.options[:through]).to eq :memberships
      expect(assoc.options[:source]).to eq :user
    end
  end

  describe 'バリデーション' do
    describe 'name' do
      it '存在しない場合は無効' do
        group = build(:group, name: nil)
        expect(group).not_to be_valid
        expect(group.errors[:name]).to be_present
      end

      it '空文字の場合は無効' do
        group = build(:group, name: '')
        expect(group).not_to be_valid
      end
    end

    describe 'share_token' do
      it '一意であること' do
        group1 = create(:group)
        group2 = build(:group, share_token: group1.share_token)
        expect(group2).not_to be_valid
        expect(group2.errors[:share_token]).to be_present
      end
    end

    describe 'threshold_target' do
      it 'core を許可する' do
        group = build(:group, threshold_target: 'core')
        expect(group).to be_valid
      end

      it 'all を許可する' do
        group = build(:group, threshold_target: 'all')
        expect(group).to be_valid
      end

      it 'nil を許可する' do
        group = build(:group, threshold_target: nil)
        expect(group).to be_valid
      end

      it '不正な値を拒否する' do
        group = build(:group, threshold_target: 'invalid')
        expect(group).not_to be_valid
        expect(group.errors[:threshold_target]).to be_present
      end
    end

    describe 'locale' do
      it 'ja を許可する' do
        group = build(:group, locale: 'ja')
        expect(group).to be_valid
      end

      it 'en を許可する' do
        group = build(:group, locale: 'en')
        expect(group).to be_valid
      end

      it '不正な値を拒否する' do
        group = build(:group, locale: 'fr')
        expect(group).not_to be_valid
        expect(group.errors[:locale]).to be_present
      end
    end
  end

  describe 'コールバック' do
    describe 'generate_share_token' do
      it '作成時に share_token が自動生成される' do
        group = build(:group, share_token: nil)
        group.valid?
        expect(group.share_token).to be_present
      end

      it '既に share_token が設定されている場合は上書きしない' do
        group = build(:group, share_token: 'custom_token')
        group.valid?
        expect(group.share_token).to eq 'custom_token'
      end

      it '生成される share_token は nanoid 形式（21文字）である' do
        group = build(:group, share_token: nil)
        group.valid?
        expect(group.share_token.length).to eq 21
      end
    end
  end

  describe 'ファクトリ' do
    it 'デフォルトファクトリが有効なレコードを作成する' do
      expect(build(:group)).to be_valid
    end
  end
end
