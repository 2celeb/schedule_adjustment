# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Membership, type: :model do
  describe 'リレーション' do
    it { expect(described_class.reflect_on_association(:user).macro).to eq :belongs_to }
    it { expect(described_class.reflect_on_association(:group).macro).to eq :belongs_to }
  end

  describe 'バリデーション' do
    describe 'role' do
      %w[owner core sub].each do |valid_role|
        it "#{valid_role} を許可する" do
          membership = build(:membership, role: valid_role)
          expect(membership).to be_valid
        end
      end

      it '不正な値を拒否する' do
        membership = build(:membership, role: 'admin')
        expect(membership).not_to be_valid
        expect(membership.errors[:role]).to be_present
      end
    end

    describe 'user_id の group_id スコープ一意性' do
      it '同じユーザーが同じグループに重複して所属できない' do
        membership = create(:membership)
        duplicate = build(:membership, user: membership.user, group: membership.group)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:user_id]).to be_present
      end

      it '同じユーザーが異なるグループに所属できる' do
        user = create(:user)
        create(:membership, user: user)
        membership2 = build(:membership, user: user)
        expect(membership2).to be_valid
      end
    end
  end

  describe 'ファクトリ' do
    it 'デフォルトファクトリが有効なレコードを作成する' do
      expect(build(:membership)).to be_valid
    end
  end
end
