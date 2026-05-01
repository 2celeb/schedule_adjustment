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

    describe 'グループメンバー上限' do
      it "メンバー数が上限（#{Group::MAX_MEMBERS}名）に達している場合、新規作成を拒否する" do
        group = create(:group)
        Group::MAX_MEMBERS.times do
          create(:membership, group: group)
        end

        new_membership = build(:membership, group: group)
        expect(new_membership).not_to be_valid
        expect(new_membership.errors[:base]).to be_present
      end

      it "メンバー数が上限未満の場合、新規作成を許可する" do
        group = create(:group)
        (Group::MAX_MEMBERS - 1).times do
          create(:membership, group: group)
        end

        new_membership = build(:membership, group: group)
        expect(new_membership).to be_valid
      end

      it "既存メンバーの更新は上限チェックの対象外" do
        group = create(:group)
        memberships = Group::MAX_MEMBERS.times.map do
          create(:membership, group: group)
        end

        # 既存メンバーの役割変更は成功する
        membership = memberships.first
        membership.role = 'core'
        expect(membership).to be_valid
      end
    end
  end

  describe 'ファクトリ' do
    it 'デフォルトファクトリが有効なレコードを作成する' do
      expect(build(:membership)).to be_valid
    end
  end
end
