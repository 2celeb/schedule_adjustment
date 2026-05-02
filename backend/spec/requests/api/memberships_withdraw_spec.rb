# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::Memberships - 退会処理", type: :request do
  # テスト用ヘルパー: Cookie セッションを設定する
  def set_session_cookie(session)
    cookies[SessionManagement::SESSION_COOKIE_NAME] = session.token
  end

  let!(:owner) { create(:user, :with_discord, display_name: "オーナー") }
  let!(:group) { create(:group, owner: owner) }
  let!(:owner_membership) { create(:membership, :owner, user: owner, group: group) }
  let!(:owner_session) { create(:session, user: owner) }

  let!(:target_user) { create(:user, :with_discord, :with_google, display_name: "退会対象ユーザー") }
  let!(:target_membership) { create(:membership, :core, user: target_user, group: group) }

  describe "DELETE /api/memberships/:id" do
    context "Owner が Cookie 認証でメンバーを退会させる場合" do
      before { set_session_cookie(owner_session) }

      it "204 No Content を返す" do
        delete "/api/memberships/#{target_membership.id}"

        expect(response).to have_http_status(:no_content)
      end

      it "ユーザーが匿名化される" do
        delete "/api/memberships/#{target_membership.id}"

        target_user.reload
        expect(target_user.anonymized).to be true
        expect(target_user.display_name).to match(/\A退会済みメンバー\d+\z/)
        expect(target_user.google_account_id).to be_nil
        expect(target_user.google_oauth_token).to be_nil
      end

      it "メンバーシップが削除される" do
        expect {
          delete "/api/memberships/#{target_membership.id}"
        }.to change { Membership.where(id: target_membership.id).count }.from(1).to(0)
      end

      it "参加可否データは保持される" do
        create(:availability, :ok, user: target_user, group: group, date: Date.current)

        delete "/api/memberships/#{target_membership.id}"

        expect(Availability.where(user: target_user, group: group).count).to eq(1)
      end

      it "calendar_caches が削除される" do
        create(:calendar_cache, user: target_user, group: group, date: Date.current)

        expect {
          delete "/api/memberships/#{target_membership.id}"
        }.to change { CalendarCache.where(user: target_user, group: group).count }.from(1).to(0)
      end

      it "セッションが無効化される" do
        create(:session, user: target_user)

        expect {
          delete "/api/memberships/#{target_membership.id}"
        }.to change { Session.where(user: target_user).count }.from(1).to(0)
      end
    end

    context "複数グループに所属するメンバーを退会させる場合" do
      let!(:other_owner) { create(:user) }
      let!(:other_group) { create(:group, owner: other_owner) }
      let!(:other_membership) { create(:membership, :core, user: target_user, group: other_group) }

      before { set_session_cookie(owner_session) }

      it "対象グループのメンバーシップのみ削除される" do
        delete "/api/memberships/#{target_membership.id}"

        expect(response).to have_http_status(:no_content)
        expect(Membership.where(user: target_user, group: group).count).to eq(0)
        expect(Membership.where(user: target_user, group: other_group).count).to eq(1)
      end

      it "discord_user_id が保持される（他グループで必要）" do
        original_discord_id = target_user.discord_user_id

        delete "/api/memberships/#{target_membership.id}"

        target_user.reload
        expect(target_user.discord_user_id).to eq(original_discord_id)
      end
    end

    context "Owner が自分自身を退会させようとする場合" do
      before { set_session_cookie(owner_session) }

      it "422 エラーを返す" do
        delete "/api/memberships/#{owner_membership.id}"

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json["error"]["message"]).to include("Owner")
      end
    end

    context "認証なしでアクセスする場合" do
      it "401 エラーを返す" do
        delete "/api/memberships/#{target_membership.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "Owner でないメンバーがアクセスする場合" do
      let!(:other_user) { create(:user, :with_google) }
      let!(:other_membership) { create(:membership, user: other_user, group: group) }
      let!(:other_session) { create(:session, user: other_user) }

      before { set_session_cookie(other_session) }

      it "403 エラーを返す" do
        delete "/api/memberships/#{target_membership.id}"

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "存在しないメンバーシップ" do
      before { set_session_cookie(owner_session) }

      it "404 エラーを返す" do
        delete "/api/memberships/999999"

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
