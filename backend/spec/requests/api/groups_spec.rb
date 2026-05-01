# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::Groups", type: :request do
  # テスト用ヘルパー: Cookie セッションを設定する
  def set_session_cookie(session)
    cookies[SessionManagement::SESSION_COOKIE_NAME] = session.token
  end

  describe "GET /api/groups/:share_token" do
    let!(:group) { create(:group, :with_times, :with_threshold, event_name: "サッカー練習") }

    context "有効な share_token の場合" do
      it "グループ情報を返す" do
        get "/api/groups/#{group.share_token}"

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["group"]["id"]).to eq(group.id)
        expect(json["group"]["name"]).to eq(group.name)
        expect(json["group"]["event_name"]).to eq("サッカー練習")
        expect(json["group"]["share_token"]).to eq(group.share_token)
        expect(json["group"]["timezone"]).to eq("Asia/Tokyo")
        expect(json["group"]["default_start_time"]).to eq("19:00")
        expect(json["group"]["default_end_time"]).to eq("22:00")
        expect(json["group"]["threshold_n"]).to eq(3)
        expect(json["group"]["threshold_target"]).to eq("core")
        expect(json["group"]["locale"]).to eq("ja")
      end

      it "認証なしでアクセスできる" do
        get "/api/groups/#{group.share_token}"

        expect(response).to have_http_status(:ok)
      end
    end

    context "無効な share_token の場合" do
      it "404 を返す" do
        get "/api/groups/invalid_token"

        expect(response).to have_http_status(:not_found)
        json = response.parsed_body
        expect(json["error"]["code"]).to eq("NOT_FOUND")
      end
    end
  end

  describe "PATCH /api/groups/:id" do
    let!(:owner) { create(:user) }
    let!(:group) { create(:group, owner: owner, name: "元の名前", event_name: "元のイベント") }
    let!(:owner_session) { create(:session, user: owner) }

    context "Owner が Cookie 認証済みの場合" do
      before { set_session_cookie(owner_session) }

      it "グループ名を更新できる" do
        patch "/api/groups/#{group.id}", params: { name: "新しい名前" }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["group"]["name"]).to eq("新しい名前")
        expect(group.reload.name).to eq("新しい名前")
      end

      it "イベント名を更新できる" do
        patch "/api/groups/#{group.id}", params: { event_name: "新しいイベント" }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["group"]["event_name"]).to eq("新しいイベント")
      end

      it "複数のフィールドを同時に更新できる" do
        patch "/api/groups/#{group.id}", params: {
          name: "更新グループ",
          event_name: "更新イベント",
          timezone: "America/New_York",
          threshold_n: 5,
          threshold_target: "all",
          locale: "en"
        }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["group"]["name"]).to eq("更新グループ")
        expect(json["group"]["event_name"]).to eq("更新イベント")
        expect(json["group"]["timezone"]).to eq("America/New_York")
        expect(json["group"]["threshold_n"]).to eq(5)
        expect(json["group"]["threshold_target"]).to eq("all")
        expect(json["group"]["locale"]).to eq("en")
      end

      it "ad_enabled を更新できる" do
        patch "/api/groups/#{group.id}", params: { ad_enabled: false }

        expect(response).to have_http_status(:ok)
        expect(group.reload.ad_enabled).to be false
      end

      it "default_start_time と default_end_time を更新できる" do
        patch "/api/groups/#{group.id}", params: {
          default_start_time: "18:00",
          default_end_time: "21:00"
        }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["group"]["default_start_time"]).to eq("18:00")
        expect(json["group"]["default_end_time"]).to eq("21:00")
      end

      it "不正な locale の場合は 422 を返す" do
        patch "/api/groups/#{group.id}", params: { locale: "fr" }

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      end

      it "不正な threshold_target の場合は 422 を返す" do
        patch "/api/groups/#{group.id}", params: { threshold_target: "invalid" }

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      end

      it "パラメータが空の場合は 400 を返す" do
        patch "/api/groups/#{group.id}"

        expect(response).to have_http_status(:bad_request)
        json = response.parsed_body
        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      end

      it "許可されていないパラメータは無視される" do
        original_token = group.share_token
        patch "/api/groups/#{group.id}", params: { share_token: "hacked_token", name: "正当な更新" }

        expect(response).to have_http_status(:ok)
        expect(group.reload.share_token).to eq(original_token)
        expect(group.name).to eq("正当な更新")
      end
    end

    context "Owner 以外のユーザーが Cookie 認証済みの場合" do
      let!(:other_user) { create(:user) }
      let!(:other_session) { create(:session, user: other_user) }

      before { set_session_cookie(other_session) }

      it "403 を返す" do
        patch "/api/groups/#{group.id}", params: { name: "不正な更新" }

        expect(response).to have_http_status(:forbidden)
        json = response.parsed_body
        expect(json["error"]["code"]).to eq("FORBIDDEN")
        expect(group.reload.name).to eq("元の名前")
      end
    end

    context "認証なしの場合" do
      it "401 を返す" do
        patch "/api/groups/#{group.id}", params: { name: "不正な更新" }

        expect(response).to have_http_status(:unauthorized)
        json = response.parsed_body
        expect(json["error"]["code"]).to eq("UNAUTHORIZED")
      end
    end

    context "存在しないグループ ID の場合" do
      before { set_session_cookie(owner_session) }

      it "404 を返す" do
        patch "/api/groups/999999", params: { name: "更新" }

        expect(response).to have_http_status(:not_found)
        json = response.parsed_body
        expect(json["error"]["code"]).to eq("NOT_FOUND")
      end
    end
  end

  describe "POST /api/groups/:id/regenerate_token" do
    let!(:owner) { create(:user) }
    let!(:group) { create(:group, owner: owner) }
    let!(:owner_session) { create(:session, user: owner) }

    context "Owner が Cookie 認証済みの場合" do
      before { set_session_cookie(owner_session) }

      it "新しい share_token を生成する" do
        original_token = group.share_token

        post "/api/groups/#{group.id}/regenerate_token"

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["group"]["share_token"]).not_to eq(original_token)
        expect(json["group"]["share_token"].length).to eq(21)
        expect(group.reload.share_token).not_to eq(original_token)
      end

      it "グループの他の情報は変更されない" do
        original_name = group.name

        post "/api/groups/#{group.id}/regenerate_token"

        expect(response).to have_http_status(:ok)
        expect(group.reload.name).to eq(original_name)
      end
    end

    context "Owner 以外のユーザーが Cookie 認証済みの場合" do
      let!(:other_user) { create(:user) }
      let!(:other_session) { create(:session, user: other_user) }

      before { set_session_cookie(other_session) }

      it "403 を返す" do
        original_token = group.share_token

        post "/api/groups/#{group.id}/regenerate_token"

        expect(response).to have_http_status(:forbidden)
        expect(group.reload.share_token).to eq(original_token)
      end
    end

    context "認証なしの場合" do
      it "401 を返す" do
        post "/api/groups/#{group.id}/regenerate_token"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "存在しないグループ ID の場合" do
      before { set_session_cookie(owner_session) }

      it "404 を返す" do
        post "/api/groups/999999/regenerate_token"

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
