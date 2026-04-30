# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DiscordConfig, type: :model do
  describe 'リレーション' do
    it { expect(described_class.reflect_on_association(:group).macro).to eq :belongs_to }
  end

  describe 'バリデーション' do
    describe 'group_id の一意性' do
      it '同じグループに複数の Discord 設定を作成できない' do
        config = create(:discord_config)
        duplicate = build(:discord_config, group: config.group)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:group_id]).to be_present
      end

      it '異なるグループには Discord 設定を作成できる' do
        create(:discord_config)
        another = build(:discord_config)
        expect(another).to be_valid
      end
    end
  end

  describe 'ファクトリ' do
    it 'デフォルトファクトリが有効なレコードを作成する' do
      expect(build(:discord_config)).to be_valid
    end
  end
end
