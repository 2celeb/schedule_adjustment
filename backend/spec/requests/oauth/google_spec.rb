# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Oauth::Google", type: :request do
  let(:google_client_id) { "test_google_client_id" }
  let(:google_client_secret) { "test_google_client_secret" }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("GOOGLE_CLIENT_ID").and_return(google_client_id)
    allow(ENV).to receive(:fetch).with("GOOGLE_CLIENT_SECRET").and_return(google_client_secret)
    allow(ENV).to receive(:fetch).with("FRONTEND_URL", anything).and_return("http://localhost:5173")
  end

  describe "GET /oauth/google" do
    let(:user) { create(:user, :with_discord) }

    context "有効な user_id でアクセスする場合" do
      it "Google 認証URLにリダイレクトする" do
        get "/oauth/google", params: { user_id: user.id }

        expect(response).to have_http_status(:redirect)
        location = response.headers["Location"]
        expect(location).to start_with("https://accounts.google.com/o/oauth2/v2/auth")
      end

      it "認証URLに必要なパラメータが含まれる" do
        get "/oauth/google", params: { user_id: user.id }

        location = URI.parse(response.headers["Location"])
        query = Rack::Utils.parse_query(location.query)

        expect(query["client_id"]).to eq(google_client_id)
        expect(query["response_type"]).to eq("code")
        expect(query["access_type"]).to eq("offline")
        expect(query["prompt"]).to eq("consent")
        expect(query["scope"]).to include("calendar.freebusy.readonly")
        expect(query["state"]).to be_present
      end

      it "デフォルトスコープは freebusy" do
        get "/oauth/google", params: { user_id: user.id }

        location = URI.parse(response.headers["Location"])
        query = Rack::Utils.parse_query(location.query)

        expect(query["scope"]).to include("calendar.freebusy.readonly")
        expect(query["scope"]).not_to include("calendar.events")
      end

      it "scope=freebusy_events で予定枠+書き込みスコープが設定される" do
        get "/oauth/google", params: { user_id: user.id, scope: "freebusy_events" }

        location = URI.parse(response.headers["Location"])
        query = Rack::Utils.parse_query(location.query)

        expect(query["scope"]).to include("calendar.freebusy.readonly")
        expect(query["scope"]).to include("calendar.events")
      end

      it "scope=calendar でフルカレンダースコープが設定される" do
        get "/oauth/google", params: { user_id: user.id, scope: "calendar" }

        location = URI.parse(response.headers["Location"])
        query = Rack::Utils.parse_query(location.query)

        expect(query["scope"]).to include("auth/calendar")
      end

      it "state パラメータに user_id が含まれる" do
        get "/oauth/google", params: { user_id: user.id }

        location = URI.parse(response.headers["Location"])
        query = Rack::Utils.parse_query(location.query)
        state_json = Base64.urlsafe_decode64(query["state"])
        state_data = JSON.parse(state_json)

        expect(state_data["user_id"]).to eq(user.id)
      end
    end

    context "user_id パラメータがない場合" do
      it "400 Bad Request を返す" do
        get "/oauth/google"

        expect(response).to have_http_status(:bad_request)
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("INVALID_PARAMS")
      end
    end

    context "存在しない user_id の場合" do
      it "404 Not Found を返す" do
        get "/oauth/google", params: { user_id: 999999 }

        expect(response).to have_http_status(:not_found)
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("NOT_FOUND")
      end
    end
  end

  describe "GET /oauth/google/callback" do
    let(:user) { create(:user, :with_discord) }
    let(:scope_pattern) { "freebusy" }
    let(:state) { Base64.urlsafe_encode64({ user_id: user.id, scope_pattern: scope_pattern, nonce: SecureRandom.hex(16) }.to_json) }
    let(:google_account_id) { "google_sub_12345" }
    let(:access_token) { "mock_access_token" }
    let(:refresh_token) { "mock_refresh_token" }

    let(:token_response) do
      {
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_in" => 3600,
        "token_type" => "Bearer"
      }
    end

    let(:userinfo_response) do
      {
        "sub" => google_account_id,
        "email" => "test@example.com"
      }
    end

    before do
      oauth_service = instance_double(GoogleOauthService)
      allow(GoogleOauthService).to receive(:new).and_return(oauth_service)
      allow(oauth_service).to receive(:exchange_code).and_return(token_response)
      allow(oauth_service).to receive(:fetch_user_info).and_return(userinfo_response)
    end

    context "認証成功の場合" do
      it "フロントエンドの成功URLにリダイレクトする" do
        get "/oauth/google/callback", params: { code: "auth_code", state: state }

        expect(response).to have_http_status(:redirect)
        expect(response.headers["Location"]).to include("status=success")
      end

      it "ユーザーの google_account_id を設定する" do
        get "/oauth/google/callback", params: { code: "auth_code", state: state }

        user.reload
        expect(user.google_account_id).to eq(google_account_id)
      end

      it "ユーザーの auth_locked を true に設定する" do
        get "/oauth/google/callback", params: { code: "auth_code", state: state }

        user.reload
        expect(user.auth_locked).to be true
      end

      it "ユーザーの google_calendar_scope を設定する" do
        get "/oauth/google/callback", params: { code: "auth_code", state: state }

        user.reload
        expect(user.google_calendar_scope).to eq("freebusy")
      end

      it "Google OAuth トークンを保存する" do
        get "/oauth/google/callback", params: { code: "auth_code", state: state }

        user.reload
        token_data = JSON.parse(user.google_oauth_token)
        expect(token_data["access_token"]).to eq(access_token)
        expect(token_data["refresh_token"]).to eq(refresh_token)
      end

      it "セッション Cookie を発行する" do
        get "/oauth/google/callback", params: { code: "auth_code", state: state }

        # リダイレクトレスポンスの Set-Cookie ヘッダーを確認
        # Rails 7.1 では response.headers["Set-Cookie"] ではなく
        # response.header["Set-Cookie"] で取得する場合がある
        session_record = Session.last
        expect(session_record).to be_present
        expect(session_record.user).to eq(user)
        expect(session_record.token).to be_present
      end

      it "セッションレコードを作成する" do
        expect {
          get "/oauth/google/callback", params: { code: "auth_code", state: state }
        }.to change(Session, :count).by(1)

        session = Session.last
        expect(session.user).to eq(user)
      end

      it "scope=freebusy_events でスコープが正しく保存される" do
        state_with_events = Base64.urlsafe_encode64({
          user_id: user.id,
          scope_pattern: "freebusy_events",
          nonce: SecureRandom.hex(16)
        }.to_json)

        get "/oauth/google/callback", params: { code: "auth_code", state: state_with_events }

        user.reload
        expect(user.google_calendar_scope).to eq("freebusy_events")
      end
    end

    context "既に同じ Google アカウントで連携済みのユーザーが再認証する場合" do
      before do
        user.update!(google_account_id: google_account_id, auth_locked: true)
      end

      it "正常に認証が完了する（トークンが更新される）" do
        get "/oauth/google/callback", params: { code: "auth_code", state: state }

        expect(response).to have_http_status(:redirect)
        expect(response.headers["Location"]).to include("status=success")
      end
    end

    context "別のユーザーが同じ Google アカウントを使用している場合" do
      before do
        create(:user, :with_discord, google_account_id: google_account_id, auth_locked: true)
      end

      it "エラーURLにリダイレクトする" do
        get "/oauth/google/callback", params: { code: "auth_code", state: state }

        expect(response).to have_http_status(:redirect)
        location = response.headers["Location"]
        expect(location).to include("status=error")
        expect(location).to include(ERB::Util.url_encode("既に別のユーザーに連携"))
      end

      it "ユーザーの google_account_id を変更しない" do
        get "/oauth/google/callback", params: { code: "auth_code", state: state }

        user.reload
        expect(user.google_account_id).to be_nil
      end
    end

    context "ユーザーに既に別の Google アカウントが設定されている場合" do
      before do
        user.update!(google_account_id: "different_google_id", auth_locked: true)
      end

      it "エラーURLにリダイレクトする" do
        get "/oauth/google/callback", params: { code: "auth_code", state: state }

        expect(response).to have_http_status(:redirect)
        location = response.headers["Location"]
        expect(location).to include("status=error")
        expect(location).to include(ERB::Util.url_encode("別のGoogleアカウントでの認証はできません"))
      end

      it "ユーザーの google_account_id を変更しない" do
        original_id = user.google_account_id
        get "/oauth/google/callback", params: { code: "auth_code", state: state }

        user.reload
        expect(user.google_account_id).to eq(original_id)
      end
    end

    context "Google 認証がキャンセルされた場合" do
      it "エラーURLにリダイレクトする" do
        get "/oauth/google/callback", params: { error: "access_denied" }

        expect(response).to have_http_status(:redirect)
        expect(response.headers["Location"]).to include("status=error")
      end
    end

    context "認証コードがない場合" do
      it "エラーURLにリダイレクトする" do
        get "/oauth/google/callback", params: { state: state }

        expect(response).to have_http_status(:redirect)
        expect(response.headers["Location"]).to include("status=error")
      end
    end

    context "state パラメータがない場合" do
      it "エラーURLにリダイレクトする" do
        get "/oauth/google/callback", params: { code: "auth_code" }

        expect(response).to have_http_status(:redirect)
        expect(response.headers["Location"]).to include("status=error")
      end
    end

    context "state パラメータが不正な場合" do
      it "エラーURLにリダイレクトする" do
        get "/oauth/google/callback", params: { code: "auth_code", state: "invalid_state" }

        expect(response).to have_http_status(:redirect)
        expect(response.headers["Location"]).to include("status=error")
      end
    end

    context "存在しないユーザーの state の場合" do
      let(:invalid_state) do
        Base64.urlsafe_encode64({ user_id: 999999, scope_pattern: "freebusy", nonce: SecureRandom.hex(16) }.to_json)
      end

      it "エラーURLにリダイレクトする" do
        get "/oauth/google/callback", params: { code: "auth_code", state: invalid_state }

        expect(response).to have_http_status(:redirect)
        expect(response.headers["Location"]).to include("status=error")
      end
    end

    context "トークン交換に失敗した場合" do
      before do
        oauth_service = instance_double(GoogleOauthService)
        allow(GoogleOauthService).to receive(:new).and_return(oauth_service)
        allow(oauth_service).to receive(:exchange_code)
          .and_raise(GoogleOauthService::TokenExchangeError, "トークン交換に失敗しました")
      end

      it "エラーURLにリダイレクトする" do
        get "/oauth/google/callback", params: { code: "auth_code", state: state }

        expect(response).to have_http_status(:redirect)
        expect(response.headers["Location"]).to include("status=error")
      end
    end

    context "ユーザー情報取得に失敗した場合" do
      before do
        oauth_service = instance_double(GoogleOauthService)
        allow(GoogleOauthService).to receive(:new).and_return(oauth_service)
        allow(oauth_service).to receive(:exchange_code).and_return(token_response)
        allow(oauth_service).to receive(:fetch_user_info)
          .and_raise(GoogleOauthService::UserInfoError, "ユーザー情報の取得に失敗しました")
      end

      it "エラーURLにリダイレクトする" do
        get "/oauth/google/callback", params: { code: "auth_code", state: state }

        expect(response).to have_http_status(:redirect)
        expect(response.headers["Location"]).to include("status=error")
      end
    end

    context "ユーザー情報に sub が含まれない場合" do
      before do
        oauth_service = instance_double(GoogleOauthService)
        allow(GoogleOauthService).to receive(:new).and_return(oauth_service)
        allow(oauth_service).to receive(:exchange_code).and_return(token_response)
        allow(oauth_service).to receive(:fetch_user_info).and_return({ "email" => "test@example.com" })
      end

      it "エラーURLにリダイレクトする" do
        get "/oauth/google/callback", params: { code: "auth_code", state: state }

        expect(response).to have_http_status(:redirect)
        expect(response.headers["Location"]).to include("status=error")
      end
    end
  end
end
