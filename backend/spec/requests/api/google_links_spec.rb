# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::GoogleLinks", type: :request do
  describe "DELETE /api/users/:user_id/google_link" do
    let(:user) { create(:user, :with_discord, :with_google) }
    let(:session_record) { create(:session, user: user) }
    let(:auth_headers) { { "Cookie" => "_session_token=#{session_record.token}" } }

    context "本人が Google 連携を解除する場合" do
      it "204 No Content を返す" do
        delete "/api/users/#{user.id}/google_link", headers: auth_headers
        expect(response).to have_http_status(:no_content)
      end

      it "auth_locked を false に更新する" do
        delete "/api/users/#{user.id}/google_link", headers: auth_headers
        user.reload
        expect(user.auth_locked).to be false
      end

      it "google_oauth_token を null に更新する" do
        delete "/api/users/#{user.id}/google_link", headers: auth_headers
        user.reload
        expect(user.google_oauth_token).to be_nil
      end

      it "google_account_id を null に更新する" do
        delete "/api/users/#{user.id}/google_link", headers: auth_headers
        user.reload
        expect(user.google_account_id).to be_nil
      end

      it "google_calendar_scope を null に更新する" do
        user.update!(google_calendar_scope: "freebusy")
        delete "/api/users/#{user.id}/google_link", headers: auth_headers
        user.reload
        expect(user.google_calendar_scope).to be_nil
      end

      it "該当ユーザーの calendar_caches を全削除する" do
        group = create(:group, owner: user)
        create(:calendar_cache, user: user, group: group, date: Date.current)
        create(:calendar_cache, user: user, group: group, date: Date.current + 1)

        expect {
          delete "/api/users/#{user.id}/google_link", headers: auth_headers
        }.to change { CalendarCache.where(user: user).count }.from(2).to(0)
      end

      it "他のユーザーの calendar_caches は削除しない" do
        group = create(:group, owner: user)
        other_user = create(:user, :with_google)
        create(:calendar_cache, user: other_user, group: group, date: Date.current)

        delete "/api/users/#{user.id}/google_link", headers: auth_headers
        expect(CalendarCache.where(user: other_user).count).to eq(1)
      end

      it "該当ユーザーの全セッションを無効化する" do
        # 追加のセッションを作成
        create(:session, user: user)
        create(:session, user: user)

        expect {
          delete "/api/users/#{user.id}/google_link", headers: auth_headers
        }.to change { Session.where(user: user).count }.to(0)
      end

      it "セッション Cookie を削除する" do
        delete "/api/users/#{user.id}/google_link", headers: auth_headers
        set_cookie = response.headers["Set-Cookie"]
        expect(set_cookie).to be_present
        expect(set_cookie).to include("_session_token=;").or include("_session_token=")
      end
    end

    context "Owner が他のメンバーの Google 連携を解除する場合" do
      let(:owner) { create(:user, :with_discord, :with_google) }
      let(:owner_session) { create(:session, user: owner) }
      let(:owner_headers) { { "Cookie" => "_session_token=#{owner_session.token}" } }
      let(:member) { create(:user, :with_discord, :with_google) }
      let(:group) { create(:group, owner: owner) }

      before do
        create(:membership, user: owner, group: group, role: 'owner')
        create(:membership, user: member, group: group, role: 'sub')
      end

      it "204 No Content を返す" do
        delete "/api/users/#{member.id}/google_link", headers: owner_headers
        expect(response).to have_http_status(:no_content)
      end

      it "メンバーの Google 連携情報をクリアする" do
        delete "/api/users/#{member.id}/google_link", headers: owner_headers
        member.reload
        expect(member.auth_locked).to be false
        expect(member.google_oauth_token).to be_nil
        expect(member.google_account_id).to be_nil
        expect(member.google_calendar_scope).to be_nil
      end

      it "メンバーの calendar_caches を全削除する" do
        create(:calendar_cache, user: member, group: group, date: Date.current)

        expect {
          delete "/api/users/#{member.id}/google_link", headers: owner_headers
        }.to change { CalendarCache.where(user: member).count }.from(1).to(0)
      end

      it "メンバーの全セッションを無効化する" do
        create(:session, user: member)

        expect {
          delete "/api/users/#{member.id}/google_link", headers: owner_headers
        }.to change { Session.where(user: member).count }.to(0)
      end
    end

    context "権限のないユーザーが他のメンバーの Google 連携を解除しようとする場合" do
      let(:other_user) { create(:user, :with_discord, :with_google) }
      let(:other_session) { create(:session, user: other_user) }
      let(:other_headers) { { "Cookie" => "_session_token=#{other_session.token}" } }
      let(:target_user) { create(:user, :with_discord, :with_google) }

      it "403 Forbidden を返す" do
        delete "/api/users/#{target_user.id}/google_link", headers: other_headers
        expect(response).to have_http_status(:forbidden)
      end

      it "エラーレスポンスを返す" do
        delete "/api/users/#{target_user.id}/google_link", headers: other_headers
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("FORBIDDEN")
      end

      it "対象ユーザーの Google 連携情報を変更しない" do
        original_google_account_id = target_user.google_account_id
        delete "/api/users/#{target_user.id}/google_link", headers: other_headers
        target_user.reload
        expect(target_user.google_account_id).to eq(original_google_account_id)
        expect(target_user.auth_locked).to be true
      end
    end

    context "セッションなしでアクセスする場合" do
      it "401 Unauthorized を返す" do
        delete "/api/users/#{user.id}/google_link"
        expect(response).to have_http_status(:unauthorized)
      end

      it "エラーレスポンスを返す" do
        delete "/api/users/#{user.id}/google_link"
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("UNAUTHORIZED")
      end
    end

    context "期限切れセッションでアクセスする場合" do
      let(:expired_session) { create(:session, :expired, user: user) }
      let(:expired_headers) { { "Cookie" => "_session_token=#{expired_session.token}" } }

      it "401 Unauthorized を返す" do
        delete "/api/users/#{user.id}/google_link", headers: expired_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "存在しないユーザーIDを指定する場合" do
      it "404 Not Found を返す" do
        delete "/api/users/999999/google_link", headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end

      it "エラーレスポンスを返す" do
        delete "/api/users/999999/google_link", headers: auth_headers
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("NOT_FOUND")
      end
    end

    context "Google 未連携のユーザーに対して解除を試みる場合" do
      let(:unlinked_user) { create(:user, :with_discord) }

      it "422 Unprocessable Entity を返す" do
        unlinked_session = create(:session, user: unlinked_user)
        delete "/api/users/#{unlinked_user.id}/google_link",
               headers: { "Cookie" => "_session_token=#{unlinked_session.token}" }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "エラーレスポンスを返す" do
        unlinked_session = create(:session, user: unlinked_user)
        delete "/api/users/#{unlinked_user.id}/google_link",
               headers: { "Cookie" => "_session_token=#{unlinked_session.token}" }
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("NOT_LINKED")
      end
    end

    context "トランザクションの整合性" do
      it "全ての変更がアトミックに実行される" do
        group = create(:group, owner: user)
        create(:calendar_cache, user: user, group: group, date: Date.current)
        create(:session, user: user) # 追加セッション

        delete "/api/users/#{user.id}/google_link", headers: auth_headers

        user.reload
        expect(user.auth_locked).to be false
        expect(user.google_oauth_token).to be_nil
        expect(user.google_account_id).to be_nil
        expect(user.google_calendar_scope).to be_nil
        expect(CalendarCache.where(user: user).count).to eq(0)
        expect(Session.where(user: user).count).to eq(0)
      end
    end
  end
end
