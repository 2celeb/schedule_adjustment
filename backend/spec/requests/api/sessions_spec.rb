# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::Sessions", type: :request do
  describe "DELETE /api/sessions" do
    context "有効なセッションでログアウトする場合" do
      let(:user) { create(:user, :with_discord) }
      let(:session_record) { create(:session, user: user) }

      it "セッションレコードを削除する" do
        session_record # セッションを事前に作成
        expect {
          delete "/api/sessions", headers: { "Cookie" => "_session_token=#{session_record.token}" }
        }.to change(Session, :count).by(-1)
      end

      it "204 No Content を返す" do
        delete "/api/sessions", headers: { "Cookie" => "_session_token=#{session_record.token}" }
        expect(response).to have_http_status(:no_content)
      end

      it "セッション Cookie をクリアする" do
        delete "/api/sessions", headers: { "Cookie" => "_session_token=#{session_record.token}" }
        # レスポンスの Set-Cookie ヘッダーで Cookie が削除されていることを確認
        set_cookie = response.headers["Set-Cookie"]
        expect(set_cookie).to be_present
        # Cookie の値が空またはmax-age=0で削除されていることを確認
        expect(set_cookie).to include("_session_token=;") | include("_session_token=")
      end

      it "削除後に同じトークンでセッションが見つからない" do
        token = session_record.token
        delete "/api/sessions", headers: { "Cookie" => "_session_token=#{token}" }
        expect(Session.find_by(token: token)).to be_nil
      end
    end

    context "セッションなしでログアウトを試みる場合" do
      it "401 Unauthorized を返す" do
        delete "/api/sessions"
        expect(response).to have_http_status(:unauthorized)
      end

      it "エラーレスポンスを返す" do
        delete "/api/sessions"
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("UNAUTHORIZED")
        expect(body["error"]["message"]).to be_present
      end
    end

    context "期限切れセッションでログアウトを試みる場合" do
      let(:user) { create(:user, :with_discord) }
      let(:expired_session) { create(:session, :expired, user: user) }

      it "401 Unauthorized を返す" do
        delete "/api/sessions", headers: { "Cookie" => "_session_token=#{expired_session.token}" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "期限切れセッションレコードを削除する" do
        expired_session # セッションを事前に作成
        expect {
          delete "/api/sessions", headers: { "Cookie" => "_session_token=#{expired_session.token}" }
        }.to change(Session, :count).by(-1)
      end
    end

    context "無効なトークンでログアウトを試みる場合" do
      it "401 Unauthorized を返す" do
        delete "/api/sessions", headers: { "Cookie" => "_session_token=invalid_token" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
