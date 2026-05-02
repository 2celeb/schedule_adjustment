# frozen_string_literal: true

require "rails_helper"

RSpec.describe MemberAnonymizer do
  let(:owner) { create(:user, :with_discord, display_name: "オーナー") }
  let(:group) { create(:group, owner: owner) }
  let!(:owner_membership) { create(:membership, :owner, user: owner, group: group) }

  let(:target_user) { create(:user, :with_discord, :with_google, display_name: "テストユーザー") }
  let!(:target_membership) { create(:membership, :core, user: target_user, group: group) }

  subject(:anonymizer) { described_class.new(target_user, group) }

  describe "#call" do
    context "正常な退会処理" do
      it "ユーザーを匿名化する" do
        result = anonymizer.call

        expect(result[:success]).to be true
        target_user.reload
        expect(target_user.anonymized).to be true
        expect(target_user.display_name).to match(/\A退会済みメンバー\d+\z/)
      end

      it "個人情報を削除する" do
        anonymizer.call
        target_user.reload

        expect(target_user.google_oauth_token).to be_nil
        expect(target_user.google_account_id).to be_nil
        expect(target_user.google_calendar_scope).to be_nil
        expect(target_user.discord_user_id).to be_nil
        expect(target_user.discord_screen_name).to be_nil
      end

      it "auth_locked を false に設定する" do
        expect(target_user.auth_locked).to be true

        anonymizer.call
        target_user.reload

        expect(target_user.auth_locked).to be false
      end

      it "calendar_caches を削除する（対象グループ分のみ）" do
        create(:calendar_cache, user: target_user, group: group, date: Date.current)
        create(:calendar_cache, user: target_user, group: group, date: Date.current + 1)

        expect { anonymizer.call }.to change { CalendarCache.where(user: target_user, group: group).count }.from(2).to(0)
      end

      it "他のグループの calendar_caches は削除しない" do
        other_group = create(:group, owner: create(:user))
        create(:calendar_cache, user: target_user, group: other_group, date: Date.current)

        anonymizer.call

        expect(CalendarCache.where(user: target_user, group: other_group).count).to eq(1)
      end

      it "セッションを全て無効化する" do
        create(:session, user: target_user)
        create(:session, user: target_user)

        expect { anonymizer.call }.to change { Session.where(user: target_user).count }.from(2).to(0)
      end

      it "メンバーシップを削除する" do
        expect { anonymizer.call }.to change { Membership.where(user: target_user, group: group).count }.from(1).to(0)
      end

      it "availabilities レコードは削除しない" do
        create(:availability, :ok, user: target_user, group: group, date: Date.current)
        create(:availability, :ng, user: target_user, group: group, date: Date.current + 1)

        expect { anonymizer.call }.not_to change { Availability.where(user: target_user, group: group).count }
      end

      it "匿名化されたユーザーを返す" do
        result = anonymizer.call

        expect(result[:user]).to eq(target_user)
        expect(result[:user].anonymized).to be true
      end
    end

    context "複数グループに所属しているユーザーの退会" do
      let(:other_owner) { create(:user) }
      let(:other_group) { create(:group, owner: other_owner) }
      let!(:other_membership) { create(:membership, :core, user: target_user, group: other_group) }

      it "discord_user_id を保持する（他グループで必要なため）" do
        original_discord_id = target_user.discord_user_id

        anonymizer.call
        target_user.reload

        expect(target_user.discord_user_id).to eq(original_discord_id)
      end

      it "Google 関連情報は削除する" do
        anonymizer.call
        target_user.reload

        expect(target_user.google_oauth_token).to be_nil
        expect(target_user.google_account_id).to be_nil
        expect(target_user.google_calendar_scope).to be_nil
      end

      it "対象グループのメンバーシップのみ削除する" do
        anonymizer.call

        expect(Membership.where(user: target_user, group: group).count).to eq(0)
        expect(Membership.where(user: target_user, group: other_group).count).to eq(1)
      end

      it "他グループの calendar_caches は削除しない" do
        create(:calendar_cache, user: target_user, group: group, date: Date.current)
        create(:calendar_cache, user: target_user, group: other_group, date: Date.current)

        anonymizer.call

        expect(CalendarCache.where(user: target_user, group: group).count).to eq(0)
        expect(CalendarCache.where(user: target_user, group: other_group).count).to eq(1)
      end

      it "他グループの availabilities は影響を受けない" do
        create(:availability, :ok, user: target_user, group: group, date: Date.current)
        create(:availability, :ok, user: target_user, group: other_group, date: Date.current)

        anonymizer.call

        expect(Availability.where(user: target_user, group: group).count).to eq(1)
        expect(Availability.where(user: target_user, group: other_group).count).to eq(1)
      end
    end

    context "単一グループのみに所属しているユーザーの退会" do
      it "discord_user_id を削除する" do
        anonymizer.call
        target_user.reload

        expect(target_user.discord_user_id).to be_nil
      end

      it "discord_screen_name を削除する" do
        anonymizer.call
        target_user.reload

        expect(target_user.discord_screen_name).to be_nil
      end
    end

    context "匿名化名の連番" do
      it "最初の退会メンバーは「退会済みメンバー1」になる" do
        anonymizer.call
        target_user.reload

        expect(target_user.display_name).to eq("退会済みメンバー1")
      end

      it "既に退会メンバーがいる場合は連番が続く" do
        create(:user, :anonymized, display_name: "退会済みメンバー1")

        anonymizer.call
        target_user.reload

        expect(target_user.display_name).to eq("退会済みメンバー2")
      end

      it "連番が飛んでいる場合は最大値+1になる" do
        create(:user, :anonymized, display_name: "退会済みメンバー1")
        create(:user, :anonymized, display_name: "退会済みメンバー5")

        anonymizer.call
        target_user.reload

        expect(target_user.display_name).to eq("退会済みメンバー6")
      end
    end

    context "既に匿名化済みのユーザー" do
      before { target_user.update!(anonymized: true, display_name: "退会済みメンバー1") }

      it "エラーを返す" do
        result = anonymizer.call

        expect(result[:success]).to be false
        expect(result[:error]).to eq("このユーザーは既に退会処理済みです。")
      end
    end

    context "グループのメンバーでないユーザー" do
      let(:non_member) { create(:user, display_name: "非メンバー") }

      it "エラーを返す" do
        result = described_class.new(non_member, group).call

        expect(result[:success]).to be false
        expect(result[:error]).to eq("このユーザーはグループのメンバーではありません。")
      end
    end

    context "Owner の退会" do
      it "エラーを返す" do
        result = described_class.new(owner, group).call

        expect(result[:success]).to be false
        expect(result[:error]).to eq("グループのOwnerは退会できません。")
      end
    end

    context "トランザクションの整合性" do
      it "途中でエラーが発生した場合はロールバックされる" do
        # メンバーシップの destroy で例外を発生させる
        allow_any_instance_of(Membership).to receive(:destroy!).and_raise(ActiveRecord::RecordInvalid.new(Membership.new))

        original_name = target_user.display_name
        result = anonymizer.call

        expect(result[:success]).to be false
        target_user.reload
        expect(target_user.display_name).to eq(original_name)
        expect(target_user.anonymized).to be false
      end
    end
  end
end
