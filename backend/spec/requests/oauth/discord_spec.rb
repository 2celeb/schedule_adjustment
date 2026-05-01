# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Oauth::Discord", type: :request do
  let(:discord_client_id) { "test_discord_client_id" }
  let(:discord_client_secret) { "test_discord_client_secret" }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("DISCORD_CLIENT_ID").and_return(discord_client_id)
    allow(ENV).to receive(:fetch).with("DISCORD_CLIENT_SECRET").and_return(discord_client_secret)
    allow(ENV).to receive(:fetch).with("FRONTEND_URL", anything).and_return("http://localhost:5173")
  end

  describe "GET /oauth/discord" do
    let(:user) { create(:user, :with_discord) }

    context "有効な user_id でアクセスする場合" do
      it "Discord 認証URLにリダイレクトする" do
        get "/oauth/discord", params: { user_id: user.id }

        expect(response).to have_http_status(:redirect)
        location = response.headers["Location"]
        expect(location).to start_with("https://discord.com/oauth2/authorize")
      end

      it "認証URLに必要なパラメータが含まれる" do
        get "/oauth/discord", params: { user_id: user.id }

        location = URI.parse(response.headers["Location"])
        query = Rack::Utils.parse_query(location.query)

        expect(query["client_id"]).to eq(discord_client_id)
        expect(query["response_type"]).to eq("code")
        expect(query["scope"]).to eq("identify")
        expect(query["state"]).to be_present
      end

      it "state パラメータに user_id が含まれる" do
        get "/oauth/discord", params: { user_id: user.id }

        location = URI.parse(response.headers["Location"])
        query = Rack::Utils.parse_query(location.query)
        state_json = Base64.urlsafe_decode64(query["state"])
        state_data = JSON.parse(state_json)

        expect(state_data["user_id"]).to eq(user.id)
      end
    end

    context "user_id パラメータがない場合" do
      it "400 Bad Request を返す" do
        get "/oauth/discord"

        expect(response).to have_http_status(:bad_request)
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("INVALID_PARAMS")
      end
    end

    context "存在しない user_id の場合" do
      it "404 Not Found を返す" do
        get "/oauth/discord", params: { user_id: 999999 }

        expect(response).to have_http_status(:not_found)
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("NOT_FOUND")
      end
    end
  end

  describe "GET /oauth/discord/callback" do
    let(:user) { create(:user, :with_discord) }
    let(:state) { Base64.urlsafe_encode64({ user_id: user.id, nonce: SecureRandom.hex(16) }.to_json) }
    let(:discord_user_id) { user.discord_user_id }
    let(:access_token) { "mock_access_token" }

    let(:token_response) do
      {
        "access_token" => access_token,
        "token_type" => "Bearer",
        "scope" => "identify"
      }
    end

    let(:userinfo_response) do
      {
        "id" => discord_user_id,
        "username" => "testuser",
        "global_name" => "テストユーザー"
      }
    end

    before do
      oauth_service = instance_double(DiscordOauthService)
      allow(DiscordOauthService).to receive(:new).and_return(oauth_service)
      allow(oauth_service).to receive(:exchange_code).and_return(token_response)
      allow(oauth_service).to receive(:fetch_user_info).and_return(userinfo_response)
    end

    context "認証成功の場合" do
      it "フロントエンドの成功URLにリダイレクトする" do
        get "/oauth/discord/callback", params: { code: "auth_code", state: state }

        expect(response).to have_http_status(:redirect)
        expect(response.headers["Location"]).to include("status=success")
        expect(response.headers["Location"]).to include("provider=discord")
      end

      it "ユーザーの auth_locked を true に設定する" do
        get "/oauth/discord/callback", params: { code: "auth_code", state: state }

        user.reload
        expect(user.auth_locked).to be true
      end

      it "セッション Cookie を発行する" do
        get "/oauth/discord/callback", params: { code: "auth_code", state: state }

        session_record = Session.last
        expect(session_record).to be_present
        expect(session_record.user).to eq(user)
        expect(session_record.token).to be_present
      end

      it "セッションレコードを作成する" do
        expect {
          get "/oauth/discord/callback", params: { code: "auth_code", state: state }
        }.to change(Session, :count).by(1)

        session = Session.last
        expect(session.user).to eq(user)
      end

      it "Discord スクリーン名を更新する" do
        get "/oauth/discord/callback", params: { code: "auth_code", state: state }

        user.reload
        expect(user.discord_screen_name).to eq("テストユーザー")
      end
    end

    context "global_name が nil の場合に username にフォールバックする" do
      let(:userinfo_response) do
        {
          "id" => discord_user_id,
          "username" => "fallback_username",
          "global_name" => nil
        }
      end

      it "username をスクリーン名として設定する" do
        get "/oauth/discord/callback", params: { code: "auth_code", state: state }

        user.reload
        expect(user.discord_screen_name).to eq("fallback_username")
      end
    end

    context "discord_user_id が未設定のユーザーの場合" do
      let(:user) { create(:user, discord_user_id: nil) }
      let(:discord_user_id) { "new_discord_id_123" }

      it "discord_user_id を設定する" do
        get "/oauth/discord/callback", params: { code: "auth_code", state: state }

        user.reload
        expect(user.discord_user_id).to eq("new_discord_id_123")
      end

      it "auth_locked を true に設定する" do
        get "/oauth/discord/callback", params: { code: "auth_code", state: state }

        user.reload
        expect(user.auth_locked).to be true
      end
    end

    context "既に同じ Discord アカウントで認証済みのユーザーが再認証する場合" do
      before do
        user.update!(auth_locked: true)
      end

      it "正常に認証が完了する" do
        get "/oauth/discord/callback", params: { code: "auth_code", state: state }

        expect(response).to have_http_status(:redirect)
        expect(response.headers["Location"]).to include("status=success")
      end
    end

    context "Discord アカウントが一致しない場合" do
      let(:userinfo_response) do
        {
          "id" => "different_discord_id",
          "username" => "otheruser",
          "global_name" => "別のユーザー"
        }
      end

      it "エラーURLにリダイレクトする" do
        get "/oauth/discord/callback", params: { code: "auth_code", state: state }

        expect(response).to have_http_status(:redirect)
        location = response.headers["Location"]
        expect(location).to include("status=error")
        expect(location).to include(ERB::Util.url_encode("Discordアカウントが一致しません"))
      end

      it "ユーザーの auth_locked を変更しない" do
        original_locked = user.auth_locked
        get "/oauth/discord/callback", params: { code: "auth_code", state: state }

        user.reload
        expect(user.auth_locked).to eq(original_locked)
      end
    end

    context "別のユーザーが同じ Discord アカウントを使用している場合" do
      let(:user) { create(:user, discord_user_id: nil) }
      let(:discord_user_id) { "shared_discord_id" }

      before do
        create(:user, :with_discord, discord_user_id: "shared_discord_id")
      end

      it "エラーURLにリダイレクトする" do
        get "/oauth/discord/callback", params: { code: "auth_code", state: state }

        expect(response).to have_http_status(:redirect)
        location = response.headers["Location"]
        expect(location).to include("status=error")
        expect(location).to include(ERB::Util.url_encode("既に別のユーザーに登録"))
      end
    end

    context "Discord 認証がキャンセルされた場合" do
      it "エラーURLにリダイレクトする" do
        get "/oauth/discord/callback", params: { error: "access_denied" }

        expect(response).to have_http_status(:redirect)
        expect(response.headers["Location"]).to include("status=error")
      end
    end

    context "認証コードがない場合" do
      it "エラーURLにリダイレクトする" do
        get "/oauth/discord/callback", params: { state: state }

        expect(response).to have_http_status(:redirect)
        expect(response.headers["Location"]).to include("status=error")
      end
    end

    context "state パラメータがない場合" do
      it "エラーURLにリダイレクトする" do
        get "/oauth/discord/callback", params: { code: "auth_code" }

        expect(response).to have_http_status(:redirect)
        expect(response.headers["Location"]).to include("status=error")
      end
    end

    context "state パラメータが不正な場合" do
      it "エラーURLにリダイレクトする" do
        get "/oauth/discord/callback", params: { code: "auth_code", state: "invalid_state" }

        expect(response).to have_http_status(:redirect)
        expect(response.headers["Location"]).to include("status=error")
      end
    end

    context "存在しないユーザーの state の場合" do
      let(:invalid_state) do
        Base64.urlsafe_encode64({ user_id: 999999, nonce: SecureRandom.hex(16) }.to_json)
      end

      it "エラーURLにリダイレクトする" do
        get "/oauth/discord/callback", params: { code: "auth_code", state: invalid_state }

        expect(response).to have_http_status(:redirect)
        expect(response.headers["Location"]).to include("status=error")
      end
    end

    context "トークン交換に失敗した場合" do
      before do
        oauth_service = instance_double(DiscordOauthService)
        allow(DiscordOauthService).to receive(:new).and_return(oauth_service)
        allow(oauth_service).to receive(:exchange_code)
          .and_raise(DiscordOauthService::TokenExchangeError, "トークン交換に失敗しました")
      end

      it "エラーURLにリダイレクトする" do
        get "/oauth/discord/callback", params: { code: "auth_code", state: state }

        expect(response).to have_http_status(:redirect)
        expect(response.headers["Location"]).to include("status=error")
      end
    end

    context "ユーザー情報取得に失敗した場合" do
      before do
        oauth_service = instance_double(DiscordOauthService)
        allow(DiscordOauthService).to receive(:new).and_return(oauth_service)
        allow(oauth_service).to receive(:exchange_code).and_return(token_response)
        allow(oauth_service).to receive(:fetch_user_info)
          .and_raise(DiscordOauthService::UserInfoError, "ユーザー情報の取得に失敗しました")
      end

      it "エラーURLにリダイレクトする" do
        get "/oauth/discord/callback", params: { code: "auth_code", state: state }

        expect(response).to have_http_status(:redirect)
        expect(response.headers["Location"]).to include("status=error")
      end
    end

    context "ユーザー情報に id が含まれない場合" do
      before do
        oauth_service = instance_double(DiscordOauthService)
        allow(DiscordOauthService).to receive(:new).and_return(oauth_service)
        allow(oauth_service).to receive(:exchange_code).and_return(token_response)
        allow(oauth_service).to receive(:fetch_user_info).and_return({ "username" => "testuser" })
      end

      it "エラーURLにリダイレクトする" do
        get "/oauth/discord/callback", params: { code: "auth_code", state: state }

        expect(response).to have_http_status(:redirect)
        expect(response.headers["Location"]).to include("status=error")
      end
    end
  end
end
