# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'リレーション' do
    it { expect(described_class.reflect_on_association(:memberships).macro).to eq :has_many }
    it { expect(described_class.reflect_on_association(:groups).macro).to eq :has_many }
    it { expect(described_class.reflect_on_association(:owned_groups).macro).to eq :has_many }
    it { expect(described_class.reflect_on_association(:availabilities).macro).to eq :has_many }
    it { expect(described_class.reflect_on_association(:availability_logs).macro).to eq :has_many }
    it { expect(described_class.reflect_on_association(:sessions).macro).to eq :has_many }
    it { expect(described_class.reflect_on_association(:calendar_caches).macro).to eq :has_many }

    it 'groups は memberships を通じて取得される' do
      assoc = described_class.reflect_on_association(:groups)
      expect(assoc.options[:through]).to eq :memberships
    end

    it 'owned_groups は Group モデルを参照する' do
      assoc = described_class.reflect_on_association(:owned_groups)
      expect(assoc.options[:class_name]).to eq 'Group'
      expect(assoc.options[:foreign_key]).to eq :owner_id
    end
  end

  describe 'バリデーション' do
    describe 'discord_user_id' do
      it 'nil を許可する' do
        user = build(:user, discord_user_id: nil)
        expect(user).to be_valid
      end

      it '一意であること' do
        create(:user, discord_user_id: 'discord_unique_1')
        user2 = build(:user, discord_user_id: 'discord_unique_1')
        expect(user2).not_to be_valid
        expect(user2.errors[:discord_user_id]).to be_present
      end
    end

    describe 'google_account_id' do
      it 'nil を許可する' do
        user = build(:user, google_account_id: nil)
        expect(user).to be_valid
      end

      it '一意であること' do
        create(:user, google_account_id: 'google_unique@example.com')
        user2 = build(:user, google_account_id: 'google_unique@example.com')
        expect(user2).not_to be_valid
        expect(user2.errors[:google_account_id]).to be_present
      end
    end

    describe 'locale' do
      it 'ja を許可する' do
        user = build(:user, locale: 'ja')
        expect(user).to be_valid
      end

      it 'en を許可する' do
        user = build(:user, locale: 'en')
        expect(user).to be_valid
      end

      it '不正な値を拒否する' do
        user = build(:user, locale: 'fr')
        expect(user).not_to be_valid
        expect(user.errors[:locale]).to be_present
      end
    end
  end

  describe '暗号化' do
    it 'google_oauth_token が暗号化されている' do
      expect(described_class.encrypted_attributes).to include(:google_oauth_token)
    end
  end

  describe 'ファクトリ' do
    it 'デフォルトファクトリが有効なレコードを作成する' do
      expect(build(:user)).to be_valid
    end

    it ':with_discord トレイトが有効なレコードを作成する' do
      expect(build(:user, :with_discord)).to be_valid
    end

    it ':with_google トレイトが有効なレコードを作成する' do
      expect(build(:user, :with_google)).to be_valid
    end
  end
end
